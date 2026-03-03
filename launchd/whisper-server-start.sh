#!/bin/bash
/opt/homebrew/bin/whisper-server \
  -m ~/.ai/models/ggml-large-v3-turbo-q8_0.bin \
  --port 49440 \
  --vad \
  --vad-model ~/.ai/models/ggml-silero-v6.2.0.bin
