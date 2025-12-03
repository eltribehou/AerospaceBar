import AppKit
import Foundation

// Parse command line arguments
let arguments = CommandLine.arguments

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
