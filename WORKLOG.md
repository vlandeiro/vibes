# Worklog

## 2026-03-12 (session 2)

### hammerspoon-whisper: Visualization refactor + recording delay fix

**Architecture: swappable visualizer system**
- Extracted all visualization code into a factory-based system with a single `ACTIVE_VISUALIZER` variable to swap between them
- Shared helpers: `updateAudioLevel`, `startMeterJob`, `stopMeterJob`
- Registry: `waveform`, `dynamic_island`, `frequency_bands`

**Recording delay fix**
- Moved `recordingJob:start()` to the very top of `startRecording()`, before the Emacs marker check (`emacsCreateMarker` is a blocking `io.popen` call that was delaying audio capture)

**Processing animation**
- Replaced icon + bouncing-dot animation with a rolling sine wave across 6 bars during transcribing/cleaning states — matches the recording bar geometry

**Waveform visualizer updates**
- Updated to 6 bars, 3px wide, 2px gaps, 28×22 canvas (matches all other visualizers)
- Added `math.sqrt(level)` scaling to reduce saturation at moderate speech levels

**Dynamic Island visualizer (volume-based)**
- Per-bar independent time constants (`smooths = {0.04, 0.48, 0.08, 0.52, 0.05, 0.22}`) so each bar is at a different stage of reacting at any given moment — this is the key mechanism for organic independent motion
- Similar weights across all bars (0.65–0.85) so all bars reach meaningful heights
- Bump offset scales with bar level so idle animation is very subtle
- Faster attack than decay

**Frequency band visualizer (experimental, shelved for now)**
- IIR filter bank: 5 cascaded single-pole low-pass filters → 6 difference bands covering 0–4kHz
- Band cutoffs: 100, 300, 700, 1500, 3000 Hz
- Per-band RMS computed from raw PCM stream (processes every sample, captures full band energy)
- Per-band sensitivity compensates for speech's natural high-frequency roll-off
- Shelved because results weren't satisfying yet; kept in registry as `frequency_bands`

**Known issue**
- Goertzel (narrow-bin) approach was tried first but failed: 31Hz bins capture too little energy per formant
- IIR approach is better but needs sensitivity tuning before it's usable

---

## 2026-03-12

### spotify-to-apple-music: Project setup and approach pivots

**Initial setup**
- Created `spotify-to-apple-music/` as a `uv` project
- Added migration script (`main.py`) using `spotipy` OAuth + Apple Music browser tokens; ISRC-first matching with fuzzy fallback

**Spotify API restriction discovery**
- Spotify's February 2026 changes require Premium for Development Mode — user doesn't have Premium
- Pivoted to browser token approach: replaced `spotipy` with direct `requests` calls using a Bearer token grabbed from DevTools on `open.spotify.com`, same pattern as Apple Music
- Added `SPOTIFY_CLIENT_TOKEN` requirement after discovering the `client-token` header in actual web player requests
- Added full browser header spoofing (`sec-fetch-*`, `sec-ch-ua`, `app-platform`, etc.)

**Rate limiting / ban**
- Python script hit 429s on `api.spotify.com/v1/me` despite correct headers
- Repeated retries triggered a 24h hard ban on the token
- Root cause: `api.spotify.com/v1` appears to actively block non-browser clients; the web player actually uses `api-partner.spotify.com` (GraphQL)

**Chrome extension PoC**
- Pivoted to a Chrome extension to run requests natively in the browser context
- Built `ext/` with MV3 manifest, fetch+XHR interceptors injected into `open.spotify.com` and `music.apple.com` at `document_start` (MAIN world), background service worker, and popup UI
- Spotify still 429s (token banned for 24h from Python attempts); Apple Music returns 403 (token capture not working despite XHR interceptor addition)
- Stopped here — will resume after the Spotify ban lifts and with further investigation into Apple Music token capture

---

## 2026-03-11 (session 2)

### What Was Worked On

Refined the `skill-eval-hook.sh`: removed the YES/NO output from response text by instructing Claude to evaluate skills in its internal thinking only, made it explicit that `Skill()` must not be called and skills should be applied directly from loaded context. Updated the `UserPromptSubmit` hook registration in `~/.claude/settings.json`. Investigated `--plugin-dir` as a path to register `~/.agents/skills/` with CC natively — decided against restructuring for now, keeping the eval hook as the integration layer.

### Issues Encountered

The `summarize-session` skill triggered a `Skill()` call in the previous session turn, which failed because the skill isn't registered as a CC skill. This exposed the need for the explicit "do NOT call Skill()" instruction in the hook.

### Solutions Adopted

Hook instruction updated to route evaluation into thinking and forbid `Skill()` calls. Skills are applied by following their loaded markdown content directly.

### Key Learnings

CC's `--plugin-dir` flag is session-only with no persistent equivalent in `settings.json`. The `UserPromptSubmit` hook system-reminder is already hidden from the main chat view — the only visible artifact was Claude's inline evaluation text, now moved to thinking.

---

## 2026-03-11

### What Was Worked On

Restructured `~/.agents/` to break down the monolithic `AGENTS.md` into discrete graph nodes. Created `skills/git-workflow.md` (merging conventional-commits), `memory/project-conventions.md` (merging task management + file structure), and updated `personas/developer.md` with behavioral constraints. Added YAML frontmatter to all skills for Agent Skills spec compatibility. Wired a `UserPromptSubmit` hook (`skill-eval-hook.sh`) that dynamically reads skill frontmatter and injects a relevance-evaluation instruction before each response.

### Issues Encountered

TOML frontmatter (`+++`) was used initially but is non-standard — caught and corrected to YAML (`---`). The `summarize-session` skill cannot be invoked via CC's `Skill()` tool because `~/.agents/skills/` isn't registered as a CC skill directory (flat `.md` files vs required `<name>/SKILL.md` structure).

### Solutions Adopted

Switched all skill frontmatter to YAML. Converted `triggers: [array]` to prose `description:` fields matching the Agent Skills open standard. Applied `summarize-session` instructions directly from loaded context as a workaround for the missing CC registration.

### Key Learnings

CC skills load only descriptions into context at session start; full content loads lazily on invocation. Discovery paths are hardcoded — `~/.agents/skills/` is invisible to CC without either symlinking into `~/.claude/skills/` or restructuring to `<name>/SKILL.md` format. The `--add-dir` flag offers a third path but requires `.claude/skills/` nesting inside the target directory.

---

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
