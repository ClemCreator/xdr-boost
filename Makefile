PREFIX ?= /usr/local
BINARY = xdr-boost
BUILD_DIR = .build
MACOS_MIN = 12.0

APP_NAME = XDR Boost
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
DMG = $(BUILD_DIR)/XDR-Boost.dmg
AGENT_PLIST = $(HOME)/Library/LaunchAgents/com.xdr-boost.agent.plist

.PHONY: build install uninstall clean launch-agent remove-agent app dmg

build:
	@mkdir -p $(BUILD_DIR)
	swiftc -O -target $(shell uname -m)-apple-macos$(MACOS_MIN) -o $(BUILD_DIR)/$(BINARY) Sources/*.swift \
		-framework Cocoa -framework MetalKit -framework Metal -framework SwiftUI -framework IOKit

# Does NOT build: run `make build` as your normal user first, then `sudo make install`
# only copies the binary. Building under sudo leaves .build/ owned by root and breaks
# every later build (levelsio/xdr-boost#5).
install:
	@test -x $(BUILD_DIR)/$(BINARY) || { echo "Run 'make build' first"; exit 1; }
	install -d $(PREFIX)/bin
	install -m 755 $(BUILD_DIR)/$(BINARY) $(PREFIX)/bin/$(BINARY)

# Run `make remove-agent` (as your user) before this if you installed the launch agent.
uninstall:
	rm -f $(PREFIX)/bin/$(BINARY)

# Install LaunchAgent to start on login (no sudo needed — it only writes to ~/Library)
launch-agent:
	@test -x $(PREFIX)/bin/$(BINARY) || { echo "Run 'make build && sudo make install' first"; exit 1; }
	@mkdir -p $(dir $(AGENT_PLIST))
	-@launchctl unload $(AGENT_PLIST) 2>/dev/null
	@sed "s|__BINARY__|$(PREFIX)/bin/$(BINARY)|g" com.xdr-boost.agent.plist > $(AGENT_PLIST)
	launchctl load $(AGENT_PLIST)
	@echo "xdr-boost will now start on login"

remove-agent:
	-launchctl unload $(AGENT_PLIST) 2>/dev/null
	rm -f $(AGENT_PLIST)

# Self-contained .app bundle (ad-hoc signed) — drag it to /Applications
app: build
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	@cp $(BUILD_DIR)/$(BINARY) "$(APP_BUNDLE)/Contents/MacOS/$(BINARY)"
	@cp Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@cp AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@codesign --force --sign - "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

dmg: app
	@rm -rf "$(BUILD_DIR)/dmg" "$(DMG)"
	@mkdir -p "$(BUILD_DIR)/dmg"
	@cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg/"
	@ln -s /Applications "$(BUILD_DIR)/dmg/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(BUILD_DIR)/dmg" -ov -format UDZO "$(DMG)"
	@rm -rf "$(BUILD_DIR)/dmg"
	@echo "Built $(DMG)"

clean:
	rm -rf $(BUILD_DIR)
