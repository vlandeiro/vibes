HAMMERSPOON_DIR  := $(HOME)/.hammerspoon
LAUNCH_AGENTS    := $(HOME)/Library/LaunchAgents
LOCAL_BIN        := $(HOME)/.local/bin
LOCAL_LOG        := $(HOME)/.local/var/log
REPO             := $(shell pwd)
UID              := $(shell id -u)

.PHONY: install load unload reload dirs

install: dirs link-whisper install-launchd install-words
	@echo ""
	@echo "Installation complete."
	@echo "  - whisper.lua is symlinked from the repo."
	@echo "  - Add 'require(\"whisper\")' to ~/.hammerspoon/init.lua if not already present."
	@echo "  - Run 'make load' to start the Whisper and Ollama servers."

dirs:
	@mkdir -p $(LOCAL_BIN) $(LOCAL_LOG)

link-whisper:
	@ln -sf $(REPO)/whisper.lua $(HAMMERSPOON_DIR)/whisper.lua
	@echo "Linked whisper.lua -> $(HAMMERSPOON_DIR)/whisper.lua"
	@ln -sf $(REPO)/launchd/whisper-server-start.sh $(LOCAL_BIN)/whisper-server-start.sh
	@chmod +x $(LOCAL_BIN)/whisper-server-start.sh
	@echo "Linked whisper-server-start.sh -> $(LOCAL_BIN)/whisper-server-start.sh"

install-launchd:
	@sed "s|/Users/virgile|$(HOME)|g" $(REPO)/launchd/com.ollama.server.plist \
		> $(LAUNCH_AGENTS)/com.ollama.server.plist
	@echo "Installed com.ollama.server.plist"
	@sed "s|/Users/virgile|$(HOME)|g" $(REPO)/launchd/com.whisper.server.plist \
		> $(LAUNCH_AGENTS)/com.whisper.server.plist
	@echo "Installed com.whisper.server.plist"

install-words:
	@if [ ! -f $(HAMMERSPOON_DIR)/whisper_words.txt ]; then \
		cp $(REPO)/whisper_words.txt $(HAMMERSPOON_DIR)/whisper_words.txt; \
		echo "Installed whisper_words.txt"; \
	else \
		echo "whisper_words.txt already exists, skipping."; \
	fi

load:
	@launchctl bootstrap gui/$(UID) $(LAUNCH_AGENTS)/com.ollama.server.plist
	@echo "Loaded com.ollama.server"
	@launchctl bootstrap gui/$(UID) $(LAUNCH_AGENTS)/com.whisper.server.plist
	@echo "Loaded com.whisper.server"

unload:
	@launchctl bootout gui/$(UID) $(LAUNCH_AGENTS)/com.ollama.server.plist 2>/dev/null || true
	@echo "Unloaded com.ollama.server"
	@launchctl bootout gui/$(UID) $(LAUNCH_AGENTS)/com.whisper.server.plist 2>/dev/null || true
	@echo "Unloaded com.whisper.server"

reload: unload load
