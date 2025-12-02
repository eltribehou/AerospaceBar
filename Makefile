.PHONY: build build-binary run debug clean install app

# Build directory for all generated files
BUILD_DIR = .build

# Default target
all: run

# Build the binary
build-binary:
	swift build -c release --build-path $(BUILD_DIR)

# Build the project (binary + .app bundle)
build: build-binary
	@echo "Creating AerospaceBar.app bundle..."
	@rm -rf $(BUILD_DIR)/AerospaceBar.app
	@mkdir -p $(BUILD_DIR)/AerospaceBar.app/Contents/MacOS
	@mkdir -p $(BUILD_DIR)/AerospaceBar.app/Contents/Resources
	@cp $(BUILD_DIR)/release/AerospaceBar $(BUILD_DIR)/AerospaceBar.app/Contents/MacOS/
	@echo "Converting icon to .icns format..."
	@mkdir -p $(BUILD_DIR)/icon.iconset
	@sips -z 16 16     icon.png --out $(BUILD_DIR)/icon.iconset/icon_16x16.png >/dev/null 2>&1
	@sips -z 32 32     icon.png --out $(BUILD_DIR)/icon.iconset/icon_16x16@2x.png >/dev/null 2>&1
	@sips -z 32 32     icon.png --out $(BUILD_DIR)/icon.iconset/icon_32x32.png >/dev/null 2>&1
	@sips -z 64 64     icon.png --out $(BUILD_DIR)/icon.iconset/icon_32x32@2x.png >/dev/null 2>&1
	@sips -z 128 128   icon.png --out $(BUILD_DIR)/icon.iconset/icon_128x128.png >/dev/null 2>&1
	@sips -z 256 256   icon.png --out $(BUILD_DIR)/icon.iconset/icon_128x128@2x.png >/dev/null 2>&1
	@sips -z 256 256   icon.png --out $(BUILD_DIR)/icon.iconset/icon_256x256.png >/dev/null 2>&1
	@sips -z 512 512   icon.png --out $(BUILD_DIR)/icon.iconset/icon_256x256@2x.png >/dev/null 2>&1
	@sips -z 512 512   icon.png --out $(BUILD_DIR)/icon.iconset/icon_512x512.png >/dev/null 2>&1
	@sips -z 1024 1024 icon.png --out $(BUILD_DIR)/icon.iconset/icon_512x512@2x.png >/dev/null 2>&1
	@iconutil -c icns $(BUILD_DIR)/icon.iconset -o $(BUILD_DIR)/AerospaceBar.app/Contents/Resources/AppIcon.icns
	@rm -rf $(BUILD_DIR)/icon.iconset
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '<plist version="1.0">' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '<dict>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleExecutable</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>AerospaceBar</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleIdentifier</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>com.aerospacebar.app</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleName</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>AerospaceBar</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundlePackageType</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>APPL</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleIconFile</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>AppIcon</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleShortVersionString</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>1.0</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleVersion</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>1</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>LSMinimumSystemVersion</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>13.0</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<key>LSUIElement</key>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '	<string>1</string>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '</dict>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo '</plist>' >> $(BUILD_DIR)/AerospaceBar.app/Contents/Info.plist
	@echo "AerospaceBar.app created successfully at $(BUILD_DIR)/AerospaceBar.app"

# Alias for build (for backwards compatibility)
app: build

# Run the project (builds if necessary)
run: build
	./.build/release/AerospaceBar

# Run the project in debug mode with verbose logging
debug: build
	./.build/release/AerospaceBar --debug

# Install the binary to /usr/local/bin
install: build-binary
	@echo "Installing AerospaceBar to /usr/local/bin..."
	@sudo cp $(BUILD_DIR)/release/AerospaceBar /usr/local/bin/aerospacebar
	@echo "Installed successfully to /usr/local/bin/aerospacebar"

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUILD_DIR)
