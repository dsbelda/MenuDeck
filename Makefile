APP_NAME    = MenuDeck
BUNDLE_ID   = com.menudeck.app
BUNDLE      = $(APP_NAME).app
BUILD_DIR   = .build/debug
RELEASE_DIR = .build/release

.PHONY: build bundle release run install clean icon

build:
	swift build 2>&1

# Redraws AppIcon.png from Tools/generate-icon.swift, then rebuilds the .icns
# from it. The generator mirrors MenuDeckGlyph, so the Dock icon and the status
# item stay the same mark.
ICONSET = .build/AppIcon.iconset
icon:
	swift Tools/generate-icon.swift
	rm -rf $(ICONSET)
	mkdir -p $(ICONSET)
	@for size in 16 32 128 256 512; do \
		sips -z $$size $$size Sources/$(APP_NAME)/Assets/AppIcon.png \
			--out $(ICONSET)/icon_$${size}x$${size}.png >/dev/null; \
		sips -z $$(($$size * 2)) $$(($$size * 2)) Sources/$(APP_NAME)/Assets/AppIcon.png \
			--out $(ICONSET)/icon_$${size}x$${size}@2x.png >/dev/null; \
	done
	iconutil -c icns $(ICONSET) -o Sources/$(APP_NAME)/Assets/AppIcon.icns
	rm -rf $(ICONSET)
	@echo "✓ Rebuilt AppIcon.icns"

release:
	swift build -c release 2>&1

# Builds a real, signed .app bundle — required for TCC (permission) prompts
# like Audio Capture to work and persist across launches.
#
# The bundle is wiped first: copying into an existing one leaves stale binaries
# behind, and codesign then seals whatever it finds next to ours.
bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	cp Sources/$(APP_NAME)/Assets/AppIcon.icns $(BUNDLE)/Contents/Resources/
	cp -R Resources/en.lproj Resources/es.lproj $(BUNDLE)/Contents/Resources/
	codesign --force --sign - --identifier $(BUNDLE_ID) $(BUNDLE)
	@echo "✓ Bundle signed: $(BUNDLE)"

app: release
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(RELEASE_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	cp Sources/$(APP_NAME)/Assets/AppIcon.icns $(BUNDLE)/Contents/Resources/
	cp -R Resources/en.lproj Resources/es.lproj $(BUNDLE)/Contents/Resources/
	codesign --force --sign - --identifier $(BUNDLE_ID) $(BUNDLE)
	@echo "✓ Release bundle signed: $(BUNDLE)"

# Always run the signed .app bundle, never the raw binary —
# raw binaries have no Info.plist/identity and TCC can't grant them permissions.
run: bundle
	killall $(APP_NAME) 2>/dev/null; true
	open $(BUNDLE)

install: app
	rm -rf /Applications/$(BUNDLE)
	cp -r $(BUNDLE) /Applications/
	@echo "✓ Installed to /Applications/$(BUNDLE)"

clean:
	rm -rf .build $(BUNDLE)
