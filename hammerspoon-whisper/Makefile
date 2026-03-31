HAMMERSPOON_DIR  := $(HOME)/.hammerspoon
LAUNCH_AGENTS    := $(HOME)/Library/LaunchAgents
LOCAL_LOG        := $(HOME)/.local/var/log
REPO             := $(shell pwd)
UID              := $(shell id -u)

.PHONY: install load unload reload dirs cleanup-legacy

install: dirs link-whisper install-launchd install-words cleanup-legacy
	@echo ""
	@echo "Installation complete."
	@echo "  - whisper.lua is symlinked from the repo."
	@echo "  - Add 'require(\"whisper\")' to ~/.hammerspoon/init.lua if not already present."
	@echo "  - Launchd agents are installed and will start automatically on next login."
	@echo "  - Run 'make load' to start them immediately without logging out."

dirs:
	@mkdir -p $(LOCAL_LOG)

link-whisper:
	@ln -sf $(REPO)/whisper.lua $(HAMMERSPOON_DIR)/whisper.lua
	@echo "Linked whisper.lua -> $(HAMMERSPOON_DIR)/whisper.lua"

install-launchd:
	@sed "s|__HOME__|$(HOME)|g" $(REPO)/launchd/com.ollama.server.plist \
		> $(LAUNCH_AGENTS)/com.ollama.server.plist
	@echo "Installed com.ollama.server.plist"
	@sed "s|__HOME__|$(HOME)|g" $(REPO)/launchd/com.whisper.server.plist \
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

reload:
	@launchctl kickstart -k gui/$(UID) $(LAUNCH_AGENTS)/com.whisper.server.plist 2>/dev/null || true
	@launchctl kickstart -k gui/$(UID) $(LAUNCH_AGENTS)/com.ollama.server.plist 2>/dev/null || true

cleanup-legacy:
	@rm -f $(HOME)/.local/bin/whisper-server-start.sh
