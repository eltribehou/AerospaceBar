.PHONY: build run clean install

# Default target
all: run

# Build the project in release mode
build:
	swift build -c release

# Run the project (builds if necessary)
run: build
	./.build/release/AerospaceBar

# Install the executable to /Applications
install: build
	cp ./.build/release/AerospaceBar /Applications/AerospaceBar

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
