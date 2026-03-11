# Worklog

## 2026-03-10

### hammerspoon-whisper: Prompt improvements and debug tooling

- Rewrote all 7 mode prompts (casual, tech, translate, notes, email, message) for clarity and stronger constraints
  - `casual`: fixed over-aggressive word removal by scoping to explicit artifact list and adding "when in doubt, keep the word"
  - `tech`: scoped to single paragraph, added concrete capitalization examples, blocked restructuring
  - `translate`: handles French-with-English-words case, added formality matching
  - `notes`: constrained to flat bullet list, blocked sub-bullets/headings
  - `email`: added casual greeting/closing examples, blocked subject line
  - `message`: removed assistant framing, blocked unsolicited greetings
- Added reproducible curl command logging on Ollama/Whisper API errors
- Updated model from qwen2.5:7b to qwen3.5:4b with thinking mode disabled
- Merged to main via `feat/whisper-prompt-improvements`

### agent-configuration: Phase 4 lint tooling

- Implemented `agents lint` subcommand with three checks:
  - `direction`: validates links flow specific to general using path depth as proxy
  - `orphans`: finds files in `~/.agents/` not reachable from any AGENTS.md, auto-discovers AGENTS.md files via `rg --files` in `~/repos`
  - `fanout`: warns on nodes exceeding outgoing link threshold (default 8)
- Restructured CLI from flat `agents-resolve` to subcommands (`agents resolve`, `agents lint`)
- Removed `agents-resolve` script alias, updated SessionStart hook to use `agents resolve`
- Added smoke test script (12 checks) and Makefile with install/test/lint targets
- Merged to main via `feat/agent-memory-graph`
