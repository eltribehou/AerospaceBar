import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager = MenuBarManager()
        menuBarManager?.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarManager?.teardown()
    }
}
