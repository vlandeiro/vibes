# Agent Memory Graph

## Context

Agents need different context for different tasks. Writing code, doing architecture work, editing markdown, and working in Emacs each benefit from different personas, skills, and accumulated knowledge. Loading everything into every session drowns signal in noise.

The problem is not what the agent knows — it's what it knows *right now*. A developer working on a TomTom tile pipeline needs Python conventions and TomTom-specific context, but not their markdown writing style guide. A selective memory system should give the agent exactly the context it needs and nothing more.

---

## Decision

Maintain agent memory as a graph of markdown files in `~/.agents/`, linked together with wikilinks. Each project declares its entry points into the graph via an `AGENTS.md` file. At session start, a script traverses the graph from those entry points to a configurable depth, collects the relevant content, and injects it into the agent's context via a provider-specific hook.

---

## Architecture

### Store Structure

```
~/.agents/
  personas/
    developer.md       ← role, working style, constraints
    architect.md       ← high-level design mode
    writer.md          ← prose-focused, minimal code
  skills/
    emacs-refactor.md  ← how to refactor in Emacs
    svelte-runes.md    ← Svelte-specific conventions
    conventional-commits.md
  memory/
    tomtom/
      pipeline.md      ← TomTom tile pipeline context
      conventions.md   ← TomTom-specific coding rules
    python-style.md    ← general Python preferences
    coding-rules.md    ← universal coding constraints
```

Personas, skills, and memory are all graph nodes. They differ semantically but not structurally — each is a markdown file with content and wikilinks to other nodes.

- **Persona**: voice, working style, constraints ("be terse", "prefer functional patterns")
- **Skill**: how to do a specific thing ("commit messages follow conventional commits")
- **Memory**: accumulated context and knowledge ("TomTom uses protobuf for tile encoding")

### Project Entry Points

Each repository contains an `AGENTS.md` file that links into the graph:

```markdown
<!-- myproject/AGENTS.md -->
[[personas/developer]]
[[skills/emacs-refactor]]
[[memory/tomtom/pipeline|depth=2]]
[[skills/conventional-commits|depth=1]]
```

Each link can specify a traversal depth. The script follows wikilinks from the target file up to that depth, collecting all reached nodes.

### Graph Traversal

At session start:

1. Read `AGENTS.md` from the project root
2. Resolve each wikilink to a file in `~/.agents/`
3. BFS from each root node to its configured depth (default: 3)
4. Deduplicate nodes reached via multiple paths
5. Concatenate content, report token count
6. Inject into agent context via a provider-specific hook

Links go from specific to general. `tomtom/pipeline.md` links to `python-style.md`, not the reverse. This ensures that pulling in project-specific context transitively includes the general knowledge it depends on, without general nodes pulling in unrelated specifics.

### Persona-Skill Composition

Personas bundle skills via wikilinks. A project links to a persona, and the persona's links pull in the relevant skills transitively:

```
AGENTS.md
  └── [[personas/developer]]
        ├── [[skills/emacs-refactor]]
        ├── [[coding-rules]]
        └── [[python-style]]
              └── [[coding-rules]]  (already visited, skipped)
```

A skill needed only for one project is linked directly from that project's `AGENTS.md`. A skill needed across many projects is linked from a persona. No special mechanism — just graph topology.

### Second Brain Integration

The graph can link into an external note system (Obsidian vault, personal wiki, etc.). Links to files outside `~/.agents/` are **terminal by default** — the script reads the target file but does not follow its outgoing links:

```markdown
<!-- ~/.agents/memory/tomtom/pipeline.md -->
[[python-style]]
[[~/notes/tomtom/tile-format]]
```

`python-style` is traversed normally. `~/notes/tomtom/tile-format` is read but its internal links are not followed. This prevents unpredictable fan-out into a note graph that wasn't designed for agent context injection.

To explicitly allow traversal into external notes:

```markdown
[[~/notes/tomtom/tile-format|traverse]]
```

All linked files must use wikilinks for their outgoing links to be traversable.

### Injection

The traversal script produces plain text. Provider-specific hooks inject it:

- **Claude Code**: pre-session hook writes to CLAUDE.md or injects via system prompt
- **Other agents**: adapter scripts translate the output into the provider's expected format

The core script is provider-agnostic. Adapters are thin — they take text in, put it where the provider expects it.

---

## Alternatives Considered

### SQLite FTS5 index with LLM-driven queries
The agent writes SQL to fetch relevant context on demand. Rejected — retrieval quality depends on the LLM writing good queries against an underspecified prompt at session start. A curated graph with explicit links produces deterministic, predictable context with no runtime guessing.

### Stuffing all configuration into every prompt
Simple but token-expensive. Causes context rot as configuration grows. The graph approach loads only what's reachable from the project's entry points.

### Provider-specific memory systems
Claude's auto-memory, OpenClaw's soul.md, etc. Not portable, not selective, and give the agent unbounded write access to its own configuration. The graph is human-curated and human-maintained.

### Per-session persona prompt
Asking the user "which persona do you want?" at the start of every session. Adds friction to the most common case. Rejected in favor of declaring personas in `AGENTS.md` — the project knows what it needs.

---

## Risks

- **Link direction discipline.** One wrong backlink in a hub node (e.g., `python-style.md` linking to `tomtom/pipeline.md`) pollutes every project that traverses through it. Requires either manual discipline or a lint check that validates links flow from specific to general.
- **Fan-out at depth.** If each node links to 3-4 others, depth 3 can reach 64+ files. Hub nodes need to be lean. The per-link depth override mitigates this.
- **Graph maintenance.** Every new memory file must be wired into the graph. Orphan files are invisible. This is a feature (no accidental context injection) but requires awareness.
- **Cross-machine portability.** `~/.agents/` needs to be synced (git, Syncthing, etc.) for the graph to work on multiple machines. Second brain links assume the same path structure.

---

## Implementation

- **Language:** Python (or shell — the core logic is ~100 lines)
- **Link syntax:** wikilinks (`[[target]]`, `[[target|depth=N]]`, `[[target|traverse]]`)
- **Resolution:** wikilink targets resolve to files within `~/.agents/` by default; absolute paths (e.g., `~/notes/...`) resolve directly
- **Output:** concatenated markdown + token count estimate
- **Injection:** provider-specific hooks (Claude Code hook as primary adapter)
- **Backing:** git

---

## Open Questions

1. Wikilink resolution — filename match (flat) vs path match (preserving directory structure)
2. Default depth — 3 is the starting point, may need tuning per use case
3. Token budget — should the script warn or truncate when assembled context exceeds a threshold?
4. Lint tooling — automated checks for link direction violations and orphan nodes
