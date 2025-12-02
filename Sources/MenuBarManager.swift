import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    private var window: NSWindow?
    private let aerospaceClient: AerospaceClient
    private let config: Config

    // Debounce timer to prevent excessive refresh calls during rapid events
    // Uses trailing-edge debouncing: waits for activity to stop before refreshing
    private var debounceTimer: Timer?

    @Published var workspaces: [String] = []
    @Published var currentWorkspace: String?
    @Published var appsPerWorkspace: [String: [AppInfo]] = [:]
    @Published var currentTime = Date()

    init() {
        let config = Config.load()
        self.config = config
        self.aerospaceClient = AerospaceClient(config: config)

        // Set up distributed notification listener for external refresh requests
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleRefreshWindowsNotification),
            name: NSNotification.Name("com.aerospacebar.refreshWindows"),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleRefreshWindowsNotification() {
        // Implement trailing-edge debouncing to batch rapid refresh requests
        // This prevents CPU/IO spikes from rapid window/workspace events (e.g., Alt+Tab spam)

        DebugLogger.log("Received refresh-windows notification")

        // Cancel any pending refresh timer
        if debounceTimer != nil {
            DebugLogger.log("Cancelling pending debounce timer")
            debounceTimer?.invalidate()
        }

        // Create new timer that will fire after the debounce interval
        // Convert milliseconds to seconds for Timer
        let debounceSeconds = TimeInterval(config.debounceInterval) / 1000.0

        DebugLogger.log("Starting debounce timer (\(config.debounceInterval)ms)")

        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceSeconds, repeats: false) { [weak self] _ in
            // Timer fired - no more events for debounce duration, safe to refresh
            DebugLogger.log("Debounce timer fired - executing refresh")
            self?.refreshWorkspaces()
        }
    }

    func setup() {
        // Get initial workspaces (no debouncing on startup - need immediate state)
        DebugLogger.log("App startup - performing initial workspace refresh")
        refreshWorkspaces()

        // Create the menubar window with the manager as observed object
        let contentView = MenuBarView(
            manager: self,
            barPosition: config.barPosition,
            colors: config.colors,
            onWorkspaceClick: { [weak self] workspace in
                self?.switchToWorkspace(workspace)
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        let hostingView = NSHostingView(rootView: contentView)

        // Create window
        let screen = NSScreen.main!
        let windowFrame = calculateWindowFrame(for: screen, position: config.barPosition)

        window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window?.contentView = hostingView
        window?.backgroundColor = NSColor(config.colors.background)
        window?.isOpaque = false
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window?.makeKeyAndOrderFront(nil)

        // Update clock every second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.currentTime = Date()
        }
    }

    private func calculateWindowFrame(for screen: NSScreen, position: BarPosition) -> NSRect {
        switch position {
        case .top:
            // Calculate actual menubar height (accounts for notch on newer Macs)
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            // Use the larger of configured size or menubar height (to accommodate notch)
            let barHeight = max(config.barSize, menuBarHeight)
            return NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y + screen.frame.height - barHeight,
                width: screen.frame.width,
                height: barHeight
            )
        case .bottom:
            return NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: screen.frame.width,
                height: config.barSize
            )
        case .left:
            return NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: config.barSize,
                height: screen.frame.height
            )
        case .right:
            return NSRect(
                x: screen.frame.origin.x + screen.frame.width - config.barSize,
                y: screen.frame.origin.y,
                width: config.barSize,
                height: screen.frame.height
            )
        }
    }

    func teardown() {
        window?.close()
        window = nil
    }

    private func refreshWorkspaces() {
        DebugLogger.log("Refreshing workspaces - querying Aerospace CLI")

        currentWorkspace = aerospaceClient.getCurrentWorkspace()
        var apps = aerospaceClient.getAppsPerWorkspace()

        // Always include current workspace, even if empty
        if let current = currentWorkspace, apps[current] == nil {
            apps[current] = []
        }

        // Assign the complete dictionary in one go
        appsPerWorkspace = apps

        // Build workspace list
        workspaces = Array(apps.keys).sorted()

        DebugLogger.log("Refresh complete - current workspace: \(currentWorkspace ?? "none"), \(workspaces.count) workspaces total")
    }

    private func switchToWorkspace(_ workspace: String) {
        DebugLogger.log("User clicked workspace '\(workspace)' - switching and refreshing")

        aerospaceClient.switchToWorkspace(workspace)
        // Refresh immediately after switching (no debouncing for user-initiated actions)
        // Small delay allows Aerospace to complete the workspace switch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshWorkspaces()
        }
    }
}
