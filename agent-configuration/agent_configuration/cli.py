"""Command-line interface for agents-resolve."""

import sys
from pathlib import Path
import argparse

from .traversal import GraphTraversal
from .output import format_output


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Resolve agent memory graph and output assembled context"
    )
    parser.add_argument(
        "agents_file",
        nargs="?",
        default="AGENTS.md",
        help="Path to AGENTS.md file (default: AGENTS.md)",
    )
    parser.add_argument(
        "--agents-root",
        default="~/.agents",
        help="Path to ~/.agents directory (default: ~/.agents)",
    )
    parser.add_argument(
        "--depth",
        type=int,
        default=3,
        help="Default traversal depth (default: 3)",
    )

    args = parser.parse_args()

    try:
        agents_file = Path(args.agents_file).expanduser().resolve()
        agents_root = Path(args.agents_root).expanduser().resolve()

        # Run traversal
        traversal = GraphTraversal(agents_root=agents_root)
        content_dict = traversal.traverse(agents_file, default_depth=args.depth)

        if not content_dict:
            print("No files found in graph traversal", file=sys.stderr)
            sys.exit(1)

        # Format and output
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


if __name__ == "__main__":
    main()
