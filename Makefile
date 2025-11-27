.PHONY: build run clean install

# Default target
all: run

# Build the project in release mode
build:
	swift build -c release

# Run the project (builds if necessary)
run: build
	./.build/release/AerospaceMenubar

# Install the executable to /Applications
install: build
	cp ./.build/release/AerospaceMenubar /Applications/AerospaceMenubar

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
