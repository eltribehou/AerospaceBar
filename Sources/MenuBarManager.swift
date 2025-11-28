import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    private var window: NSWindow?
    private let aerospaceClient: AerospaceClient
    private let config: Config
    @Published var workspaces: [String] = []
    @Published var currentWorkspace: String?
    @Published var appsPerWorkspace: [String: [AppInfo]] = [:]

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
        window?.backgroundColor = NSColor(white: 0.1, alpha: 0.95)
        window?.isOpaque = false
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window?.makeKeyAndOrderFront(nil)

        // Refresh workspaces periodically (fast refresh for responsive workspace switching)
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.refreshWorkspaces()
        }
    }

    private func calculateWindowFrame(for screen: NSScreen, position: BarPosition) -> NSRect {
        let barThickness: CGFloat = 32  // Thickness of the bar (width for left/right, height for top/bottom)

        switch position {
        case .top:
            // Calculate actual menubar height (accounts for notch on newer Macs)
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            return NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y + screen.frame.height - menuBarHeight,
                width: screen.frame.width,
                height: menuBarHeight
            )
        case .bottom:
            return NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: screen.frame.width,
                height: barThickness
            )
        case .left:
            return NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: barThickness,
                height: screen.frame.height
            )
        case .right:
            return NSRect(
                x: screen.frame.origin.x + screen.frame.width - barThickness,
                y: screen.frame.origin.y,
                width: barThickness,
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
