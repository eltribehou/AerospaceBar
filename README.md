# Aerospace Menubar

A custom menubar for macOS that displays and allows switching between Hyprspace workspaces. Designed to replace the native macOS menubar when using the Aerospace window manager.

## Features

- Custom menubar window at the top of the screen
- Displays only workspaces that have apps running in them
- Shows app icons for applications in each workspace (up to 3 icons, with a "+N" counter for additional apps)
- Fullscreen apps are indicated with a small green badge overlay on their icons
- Click any workspace to switch to it
- Current workspace is highlighted in blue
- Fast auto-refresh (300ms) for responsive workspace switching
- Runs without a dock icon
- Always visible across all spaces

## Requirements

- macOS 13.0+
- Swift 5.9+
- Hyprspace installed at `/usr/local/bin/hyprspace`

## Building

Using the Makefile:

```bash
make build
```

Or directly with Swift:

```bash
swift build -c release
```

The built binary will be at `.build/release/AerospaceMenubar`

## Running

Using the Makefile (builds if necessary):

```bash
make run
```

Or run the binary directly:

```bash
.build/release/AerospaceMenubar
```

Or run directly during development:

```bash
swift run
```

## Installation

To make it start automatically:

1. Build the release binary
2. Copy it to a permanent location (e.g., `~/bin/` or `/usr/local/bin/`)
3. Add it to your login items in System Settings

## Project Structure

- `main.swift` - Entry point, starts the NSApplication
- `AppDelegate.swift` - Handles app lifecycle
- `MenuBarManager.swift` - Creates and manages the custom menubar window
- `MenuBarView.swift` - SwiftUI view for the menubar UI
- `AerospaceClient.swift` - Communicates with the hyprspace CLI
- `AppIconHelper.swift` - Fetches and caches app icons using NSWorkspace
- `AppInfo.swift` - Data structure holding app name and fullscreen status

## How It Works

The app creates a borderless window positioned at the top of the screen:
- **AppKit NSWindow** - Borderless window positioned at screen top, always on top
- **SwiftUI** - Modern UI showing workspace buttons with app icons
- **Hyprspace CLI** - Queries workspaces and apps using:
  - `list-workspaces --focused` - Get current workspace
  - `list-windows --all --format "%{workspace}|%{app-name}|%{window-is-fullscreen}"` - Get apps per workspace with fullscreen status (determines which workspaces to show)
  - `workspace <name>` - Switch to a workspace
- **NSWorkspace** - Finds and loads app icons from the system
- A fast 300ms timer keeps the workspace list and app icons up to date

The menubar shows only workspaces with running apps as clickable buttons, each displaying app icons (up to 3 per workspace, with "+N" for additional apps). Fullscreen apps are indicated with a small green badge in the top-right corner of their icon. The current workspace is highlighted in blue, and you can click any workspace to switch to it.
