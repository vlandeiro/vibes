"""File resolver for mapping wikilink targets to absolute paths."""

from pathlib import Path
from typing import Optional


class FileResolver:
    """Resolves wikilink targets to absolute file paths."""

    def __init__(self, agents_root: Path):
        """
        Initialize resolver with agents directory root.

        Args:
            agents_root: Path to ~/.agents directory
        """
        self.agents_root = agents_root.expanduser().resolve()

    def resolve(self, target: str) -> Optional[Path]:
        """
        Resolve a wikilink target to an absolute path.

        Args:
            target: Wikilink target (e.g., 'personas/developer', '~/notes/topic')

        Returns:
            Absolute path if file exists, None otherwise
        """
        # External paths (starting with ~/ or /)
        if target.startswith("~/") or target.startswith("/"):
            path = Path(target).expanduser().resolve()
            return path if path.exists() else None

        # Internal paths within ~/.agents/
        path = self.agents_root / target
        # Add .md extension if not present
        if not path.suffix:
            path = path.with_suffix(".md")

        return path if path.exists() else None

    def is_external(self, target: str) -> bool:
        """Check if a target is external (outside ~/.agents/)."""
        return target.startswith("~/") or target.startswith("/")
