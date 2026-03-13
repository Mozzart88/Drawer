.PHONY: build run install clean

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
</dict>\n\
</plist>\n' > $(APP_DIR)/Info.plist

run: build
	@echo "Launching Drawer.app..."
	open Drawer.app

install: build
	cp -r Drawer.app /Applications/Drawer.app

clean:
	rm -rf .build Drawer.app
