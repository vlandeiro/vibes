# Worklog

## 2026-03-10 (session 2)

### hammerspoon-whisper: Emacs native text insertion

- Implemented marker-based text insertion via `emacsclient --eval`
  - At recording start (when Emacs is frontmost), creates a marker at point in the active buffer using `(copy-marker (point) t)` with insertion type `t` so the marker advances past inserted text
  - After transcription/cleaning completes, inserts the full output at the marker in a single `emacsclient` call (no per-token streaming -- avoids process spawn overhead)
  - Marker is cleaned up on completion, cancellation, or any error in the pipeline
- Key issues debugged during implementation:
  - `emacsclient --eval` evaluates in `*server*` buffer by default, not the user's active buffer. Fixed with `(with-current-buffer (window-buffer (selected-window)) ...)`
  - Single quotes in transcribed text break shell single-quoting. Fixed by escaping `'` as `\47` (Elisp octal) in the text content
  - `hs.execute` returned false success from within `hs.task` callbacks. Switched to `io.popen` for reliable cross-context execution
  - vterm buffers are read-only from Emacs's perspective. Added `derived-mode-p` check to use `vterm-send-string` instead of `insert` for terminal buffers
- Upgraded Ollama model from qwen3.5:4b to qwen3.5:9b

#### Known issues

- **Ghostty quick mode**: when Ghostty's quick terminal overlays Emacs, `hs.application.frontmostApplication()` may still return Emacs, causing the emacsclient path to activate instead of `keyStrokes`. Needs investigation into how macOS reports frontmost app for overlay/panel windows.

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
