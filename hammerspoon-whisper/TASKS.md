# Whisper.lua Refactoring & Feature Backlog

## Phase 1: Architecture Hardening & Bug Fixes
*Goal: Stabilize the core recording and processing pipeline to prevent race conditions and hangs.*

- [x] **Enforce API Timeouts**
  - Added the `--max-time` parameter to all `curl` commands in `hs.task.new`.
- [x] **Fix State Machine Collisions**
  - Update the hotkey listener logic to strictly verify `whisperStatus`.
  - Block new recording triggers if the status is `transcribing` or `cleaning` to prevent overwriting `/tmp/whisper_recording.wav` while it is still being processed.
- [ ] **Resolve Audio Buffer Race Conditions**
  - Modify `stopAndProcess()` to ensure `sox` has completely flushed the audio file before launching `ffmpeg`. 
  - Implement a brief asynchronous delay or a file-size check loop to guarantee the WAV header and data are intact.
- [ ] **Validate Emacs Context Data**
  - Prevent stale project context by adding a validation step for `/tmp/whisper_active_emacs_project`.
  - Check the file's modification time (TTL) or query the OS to confirm Emacs is actually running before appending the project-specific custom words.

## Phase 2: Core Feature Additions
*Goal: Enhance the user experience with better language handling and perceived latency.*

- [x] **Enable Streaming Text Output (Typewriter Mode)**
  - Integrated `--no-buffer` and parsed Ollama JSON chunks in real-time.
- [ ] **Implement Hardcoded Language Pinning**
  - Create new hotkey modifiers to explicitly force the Whisper API `language` parameter (e.g., pinning strictly to French or English).
  - Use this pinned language variable to automatically select the correct `system_fr` or `system_en` Ollama prompt, entirely bypassing Whisper's auto-detection.

## Phase 3: Advanced Assistant Capabilities
*Goal: Transform the tool from a passive dictation scribe into a context-aware coding assistant.*

- [ ] **Build Deep Context-Aware Code Mode**
  - Extend Hammerspoon's active window detection to read the current file extension or window title.
  - Dynamically inject the active language into the Ollama system prompt. For example, if editing a `.rs`, `.py`, or `.svelte` file, instruct Ollama to output valid syntax for that environment.
- [x] **Emacs Native Text Insertion**
  - At recording start, capture the Emacs buffer and cursor position via `emacsclient --eval` using `(with-current-buffer (window-buffer (selected-window)) (copy-marker (point) t))`.
  - After transcription and cleaning, insert the final text directly into the buffer at the captured marker position.
  - Marker has insertion type `t` so it advances past inserted text, supporting future continuous dictation.
  - Handles vterm buffers via `vterm-send-string` instead of `insert`.
  - Automatically activates when Emacs is the frontmost application at recording start.
  - **Known issue:** Ghostty quick mode overlay may cause false Emacs detection via `hs.application.frontmostApplication()`.

- [ ] **Emacs Marker-Based Insertion for Continuous Dictation**
  - The marker infrastructure is in place (insertion type `t`). Remaining work: track a second marker for chunk boundaries, handle mid-session edits, and integrate with the continuous dictation mode from Phase 4.

- [ ] **Shell Command Intent Mode (Eshell / vterm)**
  - Detect when the frontmost Emacs buffer is a terminal (`eshell-mode`, `vterm-mode`, `term-mode`, `comint-mode`).
  - In this context, skip transcription cleaning entirely and instead route the raw Whisper text through a dedicated Ollama prompt whose job is to translate natural language into a single executable shell command.
  - Example: "show me which files have been modified since yesterday" → `git diff --name-only @{yesterday}`. "find all Lua files larger than 10 kilobytes" → `find . -name "*.lua" -size +10k`.
  - Output the command into the terminal buffer at the prompt line (via `emacsclient --eval "(with-current-buffer ... (goto-char (point-max)) (insert ...))"`) so the user can review and press Enter to run it — never execute automatically.
  - Optionally add a brief natural-language comment above the command explaining what it does, for discoverability.

- [ ] **Develop Selection-Aware Editing (In-Place Refactoring)**
  - Create a new "Edit" mode hotkey.
  - When triggered, programmatically copy the currently highlighted text to the clipboard.
  - Pass the highlighted text as context to Ollama alongside the Whisper transcription.
  - Replace the original highlighted text with the Ollama output.

## Phase 4: Input & Recording Enhancements
*Goal: Make triggering and stopping recordings feel more natural and add safety limits.*

- [ ] **Push-to-Talk Mode**
  - Bind an alternate hotkey that records while held and submits on release.
  - Eliminates the toggle state machine for short utterances and reduces misfires.
- [ ] **Silence-Triggered Auto-Stop**
  - Reuse the existing sox meter pipeline to detect N consecutive seconds of silence.
  - Automatically call `stopAndProcess()` when the silence threshold is exceeded, without requiring a second hotkey press.
- [ ] **Continuous Dictation Mode**
  - A new mode where recording never fully stops between utterances. Silence detection marks chunk boundaries rather than ending the session.
  - On silence: flush the current audio buffer, immediately start a new recording buffer, and send the previous chunk to Whisper — all without interrupting the user.
  - Pipeline is parallelized: while chunk N is being Ollama-cleaned, chunk N+1 is already being Whisper-transcribed. Output each chunk at the cursor as its Ollama step completes.
  - Same hotkey toggle stops the session. If stopped mid-speech (before silence is detected), the current partial chunk is flushed and pushed through the full Whisper → Ollama pipeline before the session closes.
  - LLM cleaning applies to every chunk, same as normal mode.
- [ ] **Max Duration Guard**
  - Cap recording at a configurable duration (e.g., 90 seconds).
  - Flash the waveform icon near the limit and auto-submit when reached, preventing runaway recordings.

## Phase 5: Context Injection
*Goal: Feed ambient context into Ollama to produce more accurate and targeted output.*

- [ ] **Clipboard-as-Context**
  - Add an optional mode where the current clipboard contents are passed to Ollama alongside the transcription.
  - Useful for voice-editing a block of text that was just copied — a lightweight precursor to full selection-aware editing.
- [ ] **App-Aware Mode Auto-Switching**
  - Detect the frontmost application at recording start.
  - Automatically select `email` in Mail.app, `message` in Slack/Messages, `tech` in Emacs/VS Code, etc.
  - Keep the current mode as a manual override that persists until explicitly changed.
- [ ] **Browser URL Injection**
  - Read the active tab URL from Safari or Chrome via AppleScript.
  - Append the URL to the Ollama system prompt for research, summarization, or page-specific drafting tasks.

## Phase 6: Output & UX
*Goal: Improve confidence in the output and add safety nets.*

- [ ] **Undo Last Output**
  - Track the character count of the last typed output (including streaming chunks).
  - Bind a hotkey that programmatically sends the equivalent number of backspace keystrokes to erase it.
- [ ] **Notification Summary**
  - Post an `hs.notify` with the final cleaned text after each transcription completes.
  - Allows the user to verify what was inserted without switching focus or scrolling back.
- [ ] **Dual Output Mode (Type + Copy)**
  - Add a third output mode that types the result at the cursor *and* copies it to the clipboard simultaneously.
  - Acts as a safety net for long outputs where cursor position may be uncertain.

## Phase 7: History & Replay
*Goal: Make past transcriptions retrievable and reusable.*

- [ ] **Re-Process from History**
  - Add a menu item that opens an `hs.chooser` populated with past raw transcriptions from `whisper_history.txt`.
  - Selecting an entry re-runs it through the current mode and output target without re-recording.
- [ ] **Search History**
  - Add a searchable history browser via `hs.chooser` that filters `whisper_history.txt` entries by keyword.
  - Selecting a result copies the cleaned output to the clipboard.

## Phase 8: Model Management & Reliability
*Goal: Make the LLM layer resilient and configurable, including graceful degradation through a cascade of fallback models.*

- [ ] **Model Cascade (AI Gateway Pattern)**
  - Define an ordered list of models in config: local Ollama model(s) first, then optional cloud endpoints (e.g., OpenAI, Anthropic) as fallbacks.
  - On a timeout, non-200 response, or empty output from the primary model, automatically retry the request against the next model in the chain.
  - Each entry in the chain specifies its own `url`, `model` name, `api_key` env var, and request format (Ollama vs. OpenAI-compatible).
  - Surface which model ultimately produced the result in the notification summary and history log.
- [ ] **Per-Mode Model Assignment**
  - Allow each mode config to optionally override the default model and cascade chain.
  - For example, `casual` could use a fast small model while `email` or `notes` could target a larger or cloud model for higher quality.
- [ ] **Startup Health Check**
  - On Hammerspoon load, asynchronously verify that sox, ffmpeg, the Whisper endpoint, and the primary Ollama model all respond.
  - Post a single `hs.notify` warning listing any unreachable services, rather than failing silently mid-recording.
- [ ] **Retry with Backoff**
  - Before advancing to the next model in the cascade, retry the current model once after a short delay.
  - Handles transient failures (brief Ollama restart, network hiccup) without immediately escalating to a cloud model.
