"""Wikilink parser for extracting links from markdown."""

import re
from dataclasses import dataclass


@dataclass
class WikiLink:
    """Represents a parsed wikilink."""
    target: str
    depth: int | None = None
    traverse: bool = False

    @classmethod
    def from_string(cls, link_string: str) -> "WikiLink":
        """Parse a wikilink string like '[[target]]', '[[target|depth=2]]', or '[[target|traverse]]'."""
        # Remove outer brackets
        content = link_string.strip("[]")

        if "|" not in content:
            # Simple link: [[target]]
            return cls(target=content.strip())

        # Link with options: [[target|option]]
        parts = content.split("|", 1)
        target = parts[0].strip()
        option = parts[1].strip()

        if option == "traverse":
            return cls(target=target, traverse=True)
        elif option.startswith("depth="):
            try:
                depth = int(option.split("=", 1)[1])
                return cls(target=target, depth=depth)
            except (ValueError, IndexError):
                return cls(target=target)

        return cls(target=target)


def extract_wikilinks(markdown_content: str) -> list[WikiLink]:
    """Extract all wikilinks from markdown content."""
    pattern = r"\[\[([^\]]+)\]\]"
    matches = re.findall(pattern, markdown_content)

    wikilinks = []
    for match in matches:
        wikilink = WikiLink.from_string(f"[[{match}]]")
        wikilinks.append(wikilink)

    return wikilinks
