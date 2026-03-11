"""Graph traversal engine for resolving agent memory."""

from collections import deque
from pathlib import Path
from dataclasses import dataclass

from .parser import extract_wikilinks, WikiLink
from .resolver import FileResolver


@dataclass
class TraversalNode:
    """A node during traversal."""
    path: Path
    depth_remaining: int
    is_external: bool = False


class GraphTraversal:
    """Traverse the agent memory graph using BFS."""

    def __init__(self, agents_root: Path | None = None):
        """
        Initialize traversal with agents directory.

        Args:
            agents_root: Path to ~/.agents (defaults to ~/.agents)
        """
        if agents_root is None:
            agents_root = Path("~/.agents")
        self.agents_root = agents_root.expanduser().resolve()
        self.resolver = FileResolver(self.agents_root)
        self.visited: dict[str, str] = {}  # path -> content
        self.traversal_order: list[Path] = []

    def traverse(self, agents_file: Path, default_depth: int = 3) -> dict[str, str]:
        """
        Traverse the graph starting from an AGENTS.md file.

        Args:
            agents_file: Path to AGENTS.md
            default_depth: Default traversal depth for links without explicit depth

        Returns:
            Dict mapping file paths to content
        """
        agents_file = agents_file.expanduser().resolve()
        if not agents_file.exists():
            raise FileNotFoundError(f"AGENTS.md not found: {agents_file}")

        # Read initial AGENTS.md to get entry points
        content = agents_file.read_text(encoding="utf-8")
        entry_wikilinks = extract_wikilinks(content)

        # BFS from each entry point
        queue = deque()
        for wikilink in entry_wikilinks:
            depth = wikilink.depth if wikilink.depth is not None else default_depth
            resolved_path = self.resolver.resolve(wikilink.target)
            if resolved_path:
                is_external = self.resolver.is_external(wikilink.target)
                queue.append(
                    TraversalNode(
                        path=resolved_path,
                        depth_remaining=depth,
                        is_external=is_external,
                    )
                )

        # Traverse
        while queue:
            node = queue.popleft()
            path_str = str(node.path)

            # Skip if already visited
            if path_str in self.visited:
                continue

            # Read and store content
            try:
                file_content = node.path.read_text(encoding="utf-8")
                self.visited[path_str] = file_content
                self.traversal_order.append(node.path)
            except (OSError, UnicodeDecodeError):
                continue

            # Follow links if depth allows
            if node.depth_remaining > 1:
                wikilinks = extract_wikilinks(file_content)
                for wikilink in wikilinks:
                    resolved_path = self.resolver.resolve(wikilink.target)
                    if resolved_path:
                        path_str_next = str(resolved_path)
                        if path_str_next not in self.visited:
                            is_external = self.resolver.is_external(wikilink.target)

                            # Respect second brain boundary
                            if is_external and not wikilink.traverse:
                                # External files are terminal by default
                                new_depth = 0
                            else:
                                # Use link-specific depth or decrement current depth
                                new_depth = (
                                    wikilink.depth if wikilink.depth is not None
                                    else node.depth_remaining - 1
                                )

                            queue.append(
                                TraversalNode(
                                    path=resolved_path,
                                    depth_remaining=new_depth,
                                    is_external=is_external,
                                )
                            )

        return self.visited

    def get_traversal_order(self) -> list[Path]:
        """Get the order in which files were traversed."""
        return self.traversal_order
