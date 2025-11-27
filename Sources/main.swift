import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.setActivationPolicy(.accessory) // Run as menubar-only app
app.run()
