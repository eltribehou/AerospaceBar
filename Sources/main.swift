import AppKit
import Foundation

// Check if we're being called to trigger a refresh
if CommandLine.arguments.contains("--refresh-windows") {
    // Post distributed notification to running AerospaceBar instance
    DistributedNotificationCenter.default().post(
        name: NSNotification.Name("com.aerospacebar.refreshWindows"),
        object: nil
    )
    exit(0)
}

// Normal app startup
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.setActivationPolicy(.accessory) // Run as menubar-only app
app.run()
