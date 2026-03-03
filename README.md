# hammerspoon-whisper

A macOS voice dictation tool built on [Hammerspoon](https://www.hammerspoon.org/), [whisper.cpp](https://github.com/ggerganov/whisper.cpp), and [Ollama](https://ollama.com/). Records audio, transcribes it locally via Whisper, and optionally cleans or reformats the text using a local LLM before typing it out or copying it to the clipboard.

## How It Works

1. Press the hotkey to start recording. A waveform icon appears in the menu bar.
2. Press the hotkey again to stop. The audio is sped up via ffmpeg and sent to a local Whisper server for transcription.
3. The raw transcript is passed to Ollama with a mode-specific system prompt (or left raw).
4. The result is typed at the cursor or copied to the clipboard.

## Prerequisites

Install the following before proceeding:

- [Hammerspoon](https://www.hammerspoon.org/) — macOS automation framework
- [Ollama](https://ollama.com/) — local LLM server
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — local speech-to-text server (the `whisper-server` binary)
- `sox` and `ffmpeg` via Homebrew:

```sh
brew install sox ffmpeg
```

### Models

Download the required models to `~/.ai/models/`:

```sh
mkdir -p ~/.ai/models

# Whisper transcription model
curl -L -o ~/.ai/models/ggml-large-v3-turbo-q8_0.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin

# Silero VAD model (voice activity detection)
curl -L -o ~/.ai/models/ggml-silero-v6.2.0.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-silero-v6.2.0.bin
```

Pull the Ollama model:

```sh
ollama pull qwen2.5:7b
```

## Installation

```sh
git clone https://github.com/vlandeiro/hammerspoon-whisper.git ~/repos/hammerspoon-whisper
cd ~/repos/hammerspoon-whisper
make install
```

`make install` does the following:

- Symlinks `whisper.lua` into `~/.hammerspoon/`
- Symlinks `whisper-server-start.sh` into `~/.local/bin/`
- Copies the launchd plists into `~/Library/LaunchAgents/` (substituting the correct home directory)
- Installs a blank `whisper_words.txt` into `~/.hammerspoon/` if one does not already exist

Then add the following to `~/.hammerspoon/init.lua` if not already present:

```lua
require("whisper")
```

Finally, start the background servers:

```sh
make load
```

## Usage

| Hotkey            | Action                                              |
|-------------------|-----------------------------------------------------|
| `Cmd+Alt+R`       | Start recording / Stop and type output at cursor    |
| `Cmd+Alt+Shift+R` | Start recording / Stop and copy output to clipboard |
| `Shift+Escape`    | Cancel recording                                    |

Select the output mode from the menu bar icon before or between recordings.

## Output Modes

| Mode               | Description                                                       |
|--------------------|-------------------------------------------------------------------|
| Raw                | Unfiltered Whisper transcript, no LLM processing                  |
| Polished Casual    | Removes filler words, fixes punctuation, preserves natural tone   |
| Tech & Markdown    | Formats output as Markdown, wraps code and filenames in backticks |
| Cross-Translator   | Translates between English and French                             |
| Structured Notes   | Converts speech into a clean bullet-point list                    |
| Professional Email | Formats dictation as a structured professional email              |
| Quick Message      | Formats dictation as a casual Slack or text message               |

## Custom Vocabulary

Add words or phrases that Whisper should recognise (names, acronyms, technical terms) to:

- `~/.hammerspoon/whisper_words.txt` — global, applied to all recordings
- `.whisper_words.txt` in any project root — applied automatically when Emacs is the active app and the project is open

One word or phrase per line. Lines beginning with `#` are treated as comments.

## Server Management

```sh
make load    # Start Whisper and Ollama servers
make unload  # Stop both servers
make reload  # Restart both servers
```

Logs are written to `~/.local/var/log/`.

## Repository Structure

```
hammerspoon-whisper/
├── whisper.lua              # Main Hammerspoon script
├── whisper_words.txt        # Global custom vocabulary (template)
├── .whisper_words.txt       # Per-project vocabulary template
├── test_meter.sh            # Audio meter test script
├── TASKS.md                 # Feature backlog
├── Makefile                 # Install and server management
└── launchd/
    ├── com.ollama.server.plist       # Ollama launchd agent
    ├── com.whisper.server.plist      # Whisper launchd agent
    └── whisper-server-start.sh       # Whisper server startup script
```
