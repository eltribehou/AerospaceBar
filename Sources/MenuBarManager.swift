import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    private var window: NSWindow?
    private let aerospaceClient: AerospaceClient
    private let config: Config
    @Published var workspaces: [String] = []
    @Published var currentWorkspace: String?
    @Published var appsPerWorkspace: [String: [AppInfo]] = [:]
    @Published var currentTime = Date()

    init() {
        let config = Config.load()
        self.config = config
        self.aerospaceClient = AerospaceClient(config: config)
    }

    func setup() {
        // Get initial workspaces
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

        // Refresh workspaces periodically
        // Convert pollInterval from milliseconds to seconds
        let pollIntervalSeconds = TimeInterval(config.pollInterval) / 1000.0
        Timer.scheduledTimer(withTimeInterval: pollIntervalSeconds, repeats: true) { [weak self] _ in
            self?.refreshWorkspaces()
        }

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
    }

    private func switchToWorkspace(_ workspace: String) {
        aerospaceClient.switchToWorkspace(workspace)
        // Refresh immediately after switching
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshWorkspaces()
        }
    }
}
