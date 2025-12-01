# AerospaceBar

A minimalistic menubar for macOS designed specifically for [Aerospace](https://github.com/nikitabobko/AeroSpace).

## What it is

This is a very simple menubar to be used with Aerospace. As I hide the OSX menu bar for maximum screen real estate, I use this bar to display the workspaces, their running applications, and a clock.

Unlike macOS menubar I can put it on the side, and it doesn't grab my attention with useless settings and clutter.

## Features

- Display Aerospace workspaces
- Display the running applications in each workspace with their icon
- Display a green badge on fullscreen apps
- A clock on the right or bottom depending on orientation.
- Configurable colors 
- Compatible with Hyprspace 

## Features that might be added

- Display current keybind mode
- Maybe, allow to place each element in a different location, specify padding, things like that
- No proper external component system, I want to keep it simple and minimal, and lazy
 
## Warnings

- This app has been entirely generated with an LLM, vibe coded, yeah bro. 
Can't be assled with learning swift or spending lots of time on something like this. 
It works, fixes my problem. good enough for me. 
I don't think it should stop you from making a MR if you want to. 
- For now we simply call the aerospace cli every X ms to refresh the data, which is not ideal.   
I thought there was no way around that but in fact Aerospace exposes callbacks which should allow to invert the flow, which will be much better. 
To be done shortly. 


## Configuration

AerospaceBar looks for a configuration file in these locations (in order):
- `~/.aerospacebar.toml`
- `~/.config/aerospacebar/aerospacebar.toml`

If no config file is found, it uses sensible defaults.

### Configuration options

```toml
# Path to the aerospace binary
# Default: "/usr/local/bin/aerospace"
aerospace-path = "/usr/local/bin/aerospace"

# Bar position: "top", "bottom", "left", or "right"
# Default: "top"
bar-position = "top"

# Bar size in pixels
# Default: 25 for top/bottom, 30 for left/right
bar-size = 25

# Workspace polling interval in milliseconds (minimum 100ms)
# Default: 300
aerospace-poll-interval = 300

# Color customization (all colors support #RGB, #RRGGBB, #RRGGBBAA formats)
[colors]
background = "#1A1A1AF2"                    # Bar background
workspace-active-background = "#0066CC99"   # Active workspace background
workspace-hover-background = "#FFFFFF33"    # Workspace hover state
workspace-default-background = "#FFFFFF1A"  # Default workspace background
text-active = "#FFFFFF"                     # Active workspace text
text-inactive = "#FFFFFFB3"                 # Inactive workspace text
text-secondary = "#FFFFFF80"                # Secondary text (app counts)
text-clock = "#FFFFFFE6"                    # Clock text
fullscreen-badge-background = "#00FF00"     # Fullscreen indicator badge
fullscreen-badge-symbol = "#FFFFFF"         # Fullscreen indicator symbol
```

## Building

### Requirements
- macOS 13.0+
- Swift 5.9+
- Aerospace installed

### Build commands

Using the Makefile:
```bash
make build          # Build release binary
make run            # Build and run
make install        # Build and install the App bundle to /Applications
```

The release binary will be at `.build/release/AerospaceBar`.

## How it works

The app polls Aerospace every 300ms (configurable) to get workspace and window information:
- Displays workspaces that have running applications
- Always shows the current workspace (even if empty)
- Shows up to 3 app icons per workspace (with a "+N" counter for more)
- Green badge on fullscreen apps
- Click a workspace to switch to it
- Right-click anywhere for the quit menu

