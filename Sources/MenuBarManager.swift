import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    private var window: NSWindow?
    private let aerospaceClient = AerospaceClient()
    @Published var workspaces: [String] = []
    @Published var currentWorkspace: String?
    @Published var appsPerWorkspace: [String: [AppInfo]] = [:]

    func setup() {
        // Get initial workspaces
        refreshWorkspaces()

        // Create the menubar window
        let contentView = MenuBarView(
            workspaces: workspaces,
            currentWorkspace: currentWorkspace,
            appsPerWorkspace: appsPerWorkspace,
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
        let menuBarHeight: CGFloat = 24
        let windowFrame = NSRect(
            x: 0,
            y: screen.frame.height - menuBarHeight,
            width: screen.frame.width,
            height: menuBarHeight
        )

        window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window?.contentView = hostingView
        window?.backgroundColor = NSColor(white: 0.1, alpha: 0.95)
        window?.isOpaque = false
        window?.level = .statusBar
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window?.makeKeyAndOrderFront(nil)

        // Refresh workspaces periodically (fast refresh for responsive workspace switching)
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.refreshWorkspaces()
            self?.updateWindowContent()
        }
    }

    func teardown() {
        window?.close()
        window = nil
    }

    private func refreshWorkspaces() {
        currentWorkspace = aerospaceClient.getCurrentWorkspace()
        appsPerWorkspace = aerospaceClient.getAppsPerWorkspace()

        // Only show workspaces that have apps running in them
        workspaces = Array(appsPerWorkspace.keys).sorted()
    }

    private func updateWindowContent() {
        let contentView = MenuBarView(
            workspaces: workspaces,
            currentWorkspace: currentWorkspace,
            appsPerWorkspace: appsPerWorkspace,
            onWorkspaceClick: { [weak self] workspace in
                self?.switchToWorkspace(workspace)
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        window?.contentView = NSHostingView(rootView: contentView)
    }

    private func switchToWorkspace(_ workspace: String) {
        aerospaceClient.switchToWorkspace(workspace)
        // Refresh immediately after switching
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshWorkspaces()
            self?.updateWindowContent()
        }
    }
}
