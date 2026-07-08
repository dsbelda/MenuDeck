APP_NAME    = Clutch
BUNDLE_ID   = com.clutch.app
BUNDLE      = $(APP_NAME).app
BUILD_DIR   = .build/debug
RELEASE_DIR = .build/release

.PHONY: build bundle release run install clean

build:
	swift build 2>&1

release:
	swift build -c release 2>&1

# Builds a real, signed .app bundle — required for TCC (permission) prompts
# like Audio Capture to work and persist across launches.
bundle: build
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	codesign --force --deep --sign - --identifier $(BUNDLE_ID) $(BUNDLE)
	@echo "✓ Bundle signed: $(BUNDLE)"

app: release
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(RELEASE_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	codesign --force --deep --sign - --identifier $(BUNDLE_ID) $(BUNDLE)
	@echo "✓ Release bundle signed: $(BUNDLE)"

# Always run the signed .app bundle, never the raw binary —
# raw binaries have no Info.plist/identity and TCC can't grant them permissions.
run: bundle
	killall $(APP_NAME) 2>/dev/null; true
	open $(BUNDLE)

install: app
	cp -r $(BUNDLE) /Applications/
	@echo "✓ Installed to /Applications/$(BUNDLE)"

clean:
	rm -rf .build $(BUNDLE)
