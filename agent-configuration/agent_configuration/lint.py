"""Lint checks for the agent memory graph."""

import subprocess
from pathlib import Path

from .parser import extract_wikilinks
from .resolver import FileResolver

AGENTS_SCAN_ROOT = "~/repos"


def _collect_all_files(agents_root: Path) -> list[Path]:
    """Collect all .md files under agents_root, excluding AGENTS.md files."""
    return sorted(
        p for p in agents_root.rglob("*.md") if p.name != "AGENTS.md"
    )


def _build_link_map(
    agents_root: Path, resolver: FileResolver
) -> dict[Path, list[tuple[str, Path]]]:
    """Build a map of file -> [(raw_target, resolved_path)] for all files."""
    link_map: dict[Path, list[tuple[str, Path]]] = {}
    for md_file in _collect_all_files(agents_root):
        content = md_file.read_text(encoding="utf-8")
        wikilinks = extract_wikilinks(content)
        links = []
        for wl in wikilinks:
            resolved = resolver.resolve(wl.target)
            if resolved:
                links.append((wl.target, resolved))
        link_map[md_file] = links
    return link_map


def lint_direction(agents_root: Path) -> list[str]:
    """Check that links go from specific to general (deeper -> shallower paths).

    A file at depth N should only link to files at depth <= N.
    For example, memory/tomtom/pipeline.md (depth 3) can link to
    memory/coding-rules.md (depth 2), but not the reverse.
    """
    agents_root = agents_root.expanduser().resolve()
    resolver = FileResolver(agents_root)
    link_map = _build_link_map(agents_root, resolver)
    warnings = []

    for source, links in link_map.items():
        source_depth = len(source.relative_to(agents_root).parts)
        for raw_target, target_path in links:
            if resolver.is_external(raw_target):
                continue
            target_depth = len(target_path.relative_to(agents_root).parts)
            if target_depth > source_depth:
                warnings.append(
                    f"direction: {source.relative_to(agents_root)} -> "
                    f"[[{raw_target}]] links from general (depth {source_depth}) "
                    f"to specific (depth {target_depth})"
                )

    return warnings


def discover_agents_files(scan_root: str = AGENTS_SCAN_ROOT) -> list[Path]:
    """Find all AGENTS.md files under scan_root using ripgrep."""
    scan_path = Path(scan_root).expanduser().resolve()
    result = subprocess.run(
        ["rg", "--files", "-g", "AGENTS.md", str(scan_path)],
        capture_output=True, text=True,
    )
    return [Path(line) for line in result.stdout.strip().splitlines() if line]


def lint_orphans(agents_root: Path, agents_files: list[Path] | None = None) -> list[str]:
    """Find files in agents_root not reachable from any AGENTS.md.

    If agents_files is not provided, discovers them via ripgrep in ~/repos.
    Performs full traversal from each AGENTS.md and reports files
    in agents_root that were never visited.
    """
    from .traversal import GraphTraversal

    agents_root = agents_root.expanduser().resolve()

    if not agents_files:
        agents_files = discover_agents_files()

    all_files = set(_collect_all_files(agents_root))
    reachable: set[Path] = set()

    for agents_file in agents_files:
        agents_file = agents_file.expanduser().resolve()
        if not agents_file.exists():
            continue
        traversal = GraphTraversal(agents_root=agents_root)
        traversal.traverse(agents_file, default_depth=10)
        for path in traversal.get_traversal_order():
            reachable.add(path)

    orphans = sorted(all_files - reachable)
    return [
        f"orphan: {p.relative_to(agents_root)} is not reachable from any AGENTS.md"
        for p in orphans
    ]


def lint_fanout(agents_root: Path, threshold: int = 8) -> list[str]:
    """Warn about files with too many outgoing links.

    Hub nodes with excessive links cause fan-out during traversal.
    """
    agents_root = agents_root.expanduser().resolve()
    resolver = FileResolver(agents_root)
    link_map = _build_link_map(agents_root, resolver)
    warnings = []

    for source, links in link_map.items():
        if len(links) > threshold:
            warnings.append(
                f"fanout: {source.relative_to(agents_root)} has "
                f"{len(links)} links (threshold: {threshold})"
            )

    return warnings
