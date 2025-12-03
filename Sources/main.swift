import AppKit
import Foundation

func printHelp() {
    print("""
    AerospaceBar - Minimalistic menubar for Aerospace window manager

    Usage: aerospacebar [OPTIONS]

    Options:
      --refresh-windows    Send refresh notification to update workspaces and windows
      --refresh-mode       Send refresh notification to update mode display
      --debug              Enable debug logging output
      -h, --help           Display this help message

    When run without options, starts the menubar application.
    """)
}

// Parse command line arguments
let arguments = CommandLine.arguments

// Check for help flag
if arguments.contains("-h") || arguments.contains("--help") {
    printHelp()
    exit(0)
}

// Validate arguments - check for unknown flags
let validFlags = ["--refresh-windows", "--refresh-mode", "--debug", "-h", "--help"]
let providedFlags = arguments.dropFirst().filter { $0.hasPrefix("-") }

for flag in providedFlags {
    if !validFlags.contains(flag) {
        fputs("Error: Unknown option '\(flag)'\n\n", stderr)
        printHelp()
        exit(1)
    }
}

// Check if we're being called to trigger a refresh
if arguments.contains("--refresh-windows") {
    // Post distributed notification to running AerospaceBar instance
    DistributedNotificationCenter.default().post(
        name: NSNotification.Name("com.aerospacebar.refreshWindows"),
        object: nil
    )
    exit(0)
}

// Check if we're being called to trigger a mode refresh
if arguments.contains("--refresh-mode") {
    // Post distributed notification to running AerospaceBar instance
    DistributedNotificationCenter.default().post(
        name: NSNotification.Name("com.aerospacebar.refreshMode"),
        object: nil
    )
    exit(0)
}

// Enable debug logging if --debug flag is present
if arguments.contains("--debug") {
    DebugLogger.isEnabled = true
    DebugLogger.log("Debug mode enabled")
}

// Normal app startup
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.setActivationPolicy(.accessory) // Run as menubar-only app
app.run()
