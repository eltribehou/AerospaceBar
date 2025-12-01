.PHONY: build run clean install app

# Default target
all: run

# Build the project in release mode
build:
	swift build -c release

# Build a proper .app bundle
app: build
	@echo "Creating AerospaceBar.app bundle..."
	@rm -rf AerospaceBar.app
	@mkdir -p AerospaceBar.app/Contents/MacOS
	@mkdir -p AerospaceBar.app/Contents/Resources
	@cp ./.build/release/AerospaceBar AerospaceBar.app/Contents/MacOS/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > AerospaceBar.app/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> AerospaceBar.app/Contents/Info.plist
	@echo '<plist version="1.0">' >> AerospaceBar.app/Contents/Info.plist
	@echo '<dict>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleExecutable</key>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<string>AerospaceBar</string>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleIdentifier</key>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<string>com.aerospacebar.app</string>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleName</key>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<string>AerospaceBar</string>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundlePackageType</key>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<string>APPL</string>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleShortVersionString</key>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<string>1.0</string>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<key>CFBundleVersion</key>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<string>1</string>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<key>LSMinimumSystemVersion</key>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<string>13.0</string>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<key>LSUIElement</key>' >> AerospaceBar.app/Contents/Info.plist
	@echo '	<string>1</string>' >> AerospaceBar.app/Contents/Info.plist
	@echo '</dict>' >> AerospaceBar.app/Contents/Info.plist
	@echo '</plist>' >> AerospaceBar.app/Contents/Info.plist
	@echo "AerospaceBar.app created successfully"

# Run the project (builds if necessary)
run: build
	./.build/release/AerospaceBar

# Install the .app bundle to /Applications
install: app
	@echo "Installing AerospaceBar.app to /Applications..."
	@rm -rf /Applications/AerospaceBar.app
	@cp -r AerospaceBar.app /Applications/
	@echo "Installed successfully. You may need to restart Spotlight/Alfred for it to be indexed."

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
	rm -rf AerospaceBar.app
