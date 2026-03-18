.PHONY: build run install clean test coverage preset

BINARY = .build/release/Drawer
APP_DIR = Drawer.app/Contents
MACOS_DIR = $(APP_DIR)/MacOS
RES_DIR = $(APP_DIR)/Resources

build:
	@echo "Building..."
	swift build -c release 2>&1
	@echo "Creating app bundle..."
	rm -rf Drawer.app
	mkdir -p $(MACOS_DIR) $(RES_DIR)
	cp $(BINARY) $(MACOS_DIR)/Drawer
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n\
<plist version="1.0">\n\
<dict>\n\
    <key>CFBundleExecutable</key>\n\
    <string>Drawer</string>\n\
    <key>CFBundleIdentifier</key>\n\
    <string>com.drawer.app</string>\n\
    <key>CFBundleName</key>\n\
    <string>Drawer</string>\n\
    <key>CFBundleVersion</key>\n\
    <string>1.0</string>\n\
    <key>CFBundleShortVersionString</key>\n\
    <string>1.0</string>\n\
    <key>NSPrincipalClass</key>\n\
    <string>NSApplication</string>\n\
    <key>LSUIElement</key>\n\
    <true/>\n\
    <key>NSHighResolutionCapable</key>\n\
    <true/>\n\
    <key>NSScreenCaptureUsageDescription</key>\n\
    <string>Drawer needs screen access to record your screen.</string>\n\
    <key>NSMicrophoneUsageDescription</key>\n\
    <string>Drawer needs microphone access to record audio.</string>\n\
    <key>NSInputMonitoringUsageDescription</key>\n\
    <string>Drawer needs input monitoring to display key presses during recording.</string>\n\
</dict>\n\
</plist>\n' > $(APP_DIR)/Info.plist

run: build
	@echo "Launching Drawer.app..."
	open Drawer.app

install: build
	rm -fr /Applications/Drawer.app
	cp -r Drawer.app /Applications/Drawer.app

test:
	swift test

preset:
	tccutil reset All com.drawer.app

coverage:
	swift test --enable-code-coverage
	xcrun llvm-cov report \
	  .build/debug/DrawerPackageTests.xctest/Contents/MacOS/DrawerPackageTests \
	  -instr-profile .build/debug/codecov/default.profdata \
	  --ignore-filename-regex='Tests/' \
	  2>&1

clean:
	rm -rf .build Drawer.app
