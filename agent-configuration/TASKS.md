# Tasks

## Phase 1: Foundation

- [x] Create `~/.agents/` directory structure (`personas/`, `skills/`, `memory/`)
- [x] Write seed content: one persona (`developer.md`), one skill (`conventional-commits.md`), one memory file (`coding-rules.md`) with wikilinks between them
- [x] Write a sample `AGENTS.md` that links into the seed files
- [x] Decide wikilink resolution convention: filename match (flat) vs path match (preserving directory structure) — **chosen: path match**

## Phase 2: Core Traversal

- [x] Wikilink parser — extract `[[target]]`, `[[target|depth=N]]`, `[[target|traverse]]` from markdown content
- [x] File resolver — map wikilink target to absolute path within `~/.agents/` (or external path for `~/...` targets)
- [x] BFS traversal with per-link depth control and deduplication
- [x] Second brain boundary rule — external links are terminal by default; `|traverse` opts in to following their outgoing links
- [x] Token count estimation on assembled output (rough char/4 is fine to start)

## Phase 3: Injection

- [ ] CLI entry point (`agents-resolve` or similar) — reads an `AGENTS.md` path, runs traversal, outputs assembled markdown to stdout
- [ ] Claude Code adapter — `SessionStart` hook that calls the CLI and injects output into system prompt

## Phase 4: Tooling

- [ ] Lint: link direction validation (links should go specific -> general only)
- [ ] Lint: orphan node detection (files in `~/.agents/` not reachable from any `AGENTS.md`)
- [ ] Lint: fan-out warning (nodes exceeding a link count threshold)

## Phase 5: Adapters

- [ ] Adapter interface for other agents (Cursor, Aider, etc.)
