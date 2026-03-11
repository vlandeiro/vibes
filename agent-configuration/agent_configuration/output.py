"""Output formatting with metadata and table of contents."""

from pathlib import Path
import re
from datetime import datetime


def estimate_tokens(text: str) -> int:
    """Estimate token count using rough char/4 heuristic."""
    return max(1, len(text) // 4)


def extract_headings(markdown_text: str) -> list[tuple[int, str]]:
    """
    Extract headings from markdown.

    Returns:
        List of (level, heading_text) tuples
    """
    headings = []
    for line in markdown_text.split("\n"):
        match = re.match(r"^(#{1,6})\s+(.+)$", line)
        if match:
            level = len(match.group(1))
            text = match.group(2)
            headings.append((level, text))
    return headings


def generate_toc(headings: list[tuple[int, str]]) -> str:
    """Generate a markdown table of contents from headings."""
    if not headings:
        return ""

    lines = ["# Table of Contents\n"]
    min_level = min((level for level, _ in headings), default=1)

    for level, text in headings:
        indent = "  " * (level - min_level)
        # Convert heading to anchor link (simplified)
        anchor = text.lower().replace(" ", "-").replace(".", "")
        lines.append(f"{indent}- [{text}](#{anchor})")

    return "\n".join(lines) + "\n"


def format_output(
    content_dict: dict[str, str],
    traversal_order: list[Path],
    agents_file: Path,
) -> str:
    """
    Format traversed content with metadata header and table of contents.

    Args:
        content_dict: Dict mapping paths to file content
        traversal_order: Order in which files were traversed
        agents_file: Path to the AGENTS.md that was traversed from

    Returns:
        Formatted output with TOML frontmatter, TOC, and content
    """
    # Assemble content in traversal order
    full_content = "\n\n".join(
        content_dict[str(path)] for path in traversal_order
    )

    # Estimate tokens
    token_count = estimate_tokens(full_content)

    # Extract headings and generate TOC
    headings = extract_headings(full_content)
    toc = generate_toc(headings)

    # Build TOML frontmatter
    file_count = len(content_dict)
    agents_rel = agents_file.relative_to(Path.home()) if agents_file.exists() else agents_file

    frontmatter = f"""+++
title = "Agent Context"
timestamp = "{datetime.now().isoformat()}"
file_count = {file_count}
token_estimate = {token_count}
traversal_source = "{agents_rel}"
+++
"""

    # Combine: frontmatter + TOC + content
    output = frontmatter + "\n" + toc + "\n" + full_content
    return output
