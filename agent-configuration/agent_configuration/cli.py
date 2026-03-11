"""Command-line interface for agents-resolve."""

import sys
from pathlib import Path
import argparse

from .traversal import GraphTraversal
from .output import format_output
from .lint import lint_direction, lint_orphans, lint_fanout


def cmd_resolve(args):
    """Resolve agent memory graph and output assembled context."""
    try:
        agents_file = Path(args.agents_file).expanduser().resolve()
        agents_root = Path(args.agents_root).expanduser().resolve()

        traversal = GraphTraversal(agents_root=agents_root)
        content_dict = traversal.traverse(agents_file, default_depth=args.depth)

        if not content_dict:
            print("No files found in graph traversal", file=sys.stderr)
            sys.exit(1)

        output = format_output(
            content_dict,
            traversal.get_traversal_order(),
            agents_file,
        )
        print(output)

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def cmd_lint(args):
    """Run lint checks on the agent memory graph."""
    agents_root = Path(args.agents_root).expanduser().resolve()

    if not agents_root.exists():
        print(f"Error: agents root not found: {agents_root}", file=sys.stderr)
        sys.exit(1)

    warnings: list[str] = []
    checks = args.checks

    if "all" in checks or "direction" in checks:
        warnings.extend(lint_direction(agents_root))

    if "all" in checks or "orphans" in checks:
        agents_files = (
            [Path(p).expanduser().resolve() for p in args.agents_files]
            if args.agents_files else None
        )
        warnings.extend(lint_orphans(agents_root, agents_files))

    if "all" in checks or "fanout" in checks:
        warnings.extend(lint_fanout(agents_root, threshold=args.fanout_threshold))

    if warnings:
        for w in warnings:
            print(w)
        sys.exit(1)
    else:
        print("No issues found.")


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Agent memory graph tools"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # resolve subcommand
    resolve_parser = subparsers.add_parser(
        "resolve",
        help="Resolve agent memory graph and output assembled context",
    )
    resolve_parser.add_argument(
        "agents_file",
        nargs="?",
        default="AGENTS.md",
        help="Path to AGENTS.md file (default: AGENTS.md)",
    )
    resolve_parser.add_argument(
        "--agents-root",
        default="~/.agents",
        help="Path to ~/.agents directory (default: ~/.agents)",
    )
    resolve_parser.add_argument(
        "--depth",
        type=int,
        default=3,
        help="Default traversal depth (default: 3)",
    )
    resolve_parser.set_defaults(func=cmd_resolve)

    # lint subcommand
    lint_parser = subparsers.add_parser(
        "lint",
        help="Lint the agent memory graph",
    )
    lint_parser.add_argument(
        "checks",
        nargs="*",
        default=["all"],
        help="Checks to run: direction, orphans, fanout, all (default: all)",
    )
    lint_parser.add_argument(
        "--agents-root",
        default="~/.agents",
        help="Path to ~/.agents directory (default: ~/.agents)",
    )
    lint_parser.add_argument(
        "--agents-files",
        nargs="+",
        default=[],
        help="Paths to AGENTS.md files for orphan detection",
    )
    lint_parser.add_argument(
        "--fanout-threshold",
        type=int,
        default=8,
        help="Max outgoing links before warning (default: 8)",
    )
    lint_parser.set_defaults(func=cmd_lint)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
