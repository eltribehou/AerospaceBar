import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    private var windows: [NSWindow] = []
    private let aerospaceClient = AerospaceClient()
    @Published var workspaces: [String] = []
    @Published var currentWorkspace: String?
    @Published var appsPerWorkspace: [String: [AppInfo]] = [:]

    func setup() {
        // Get initial workspaces
        refreshWorkspaces()

        // Create menubar windows for all screens
        createWindowsForAllScreens()

        // Refresh workspaces periodically (fast refresh for responsive workspace switching)
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.refreshWorkspaces()
            self?.updateWindowContent()
        }

        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recreateWindows()
        }
    }

    func teardown() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }

    private func createWindowsForAllScreens() {
        for screen in NSScreen.screens {
            // Calculate actual menubar height (accounts for notch on newer Macs)
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY

            // Position window at the absolute top of the screen, ignoring safe areas
            // This allows drawing into the notch area on newer Macs
            let windowFrame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y + screen.frame.height - menuBarHeight,
                width: screen.frame.width,
                height: menuBarHeight
            )

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

            let window = NSWindow(
                contentRect: windowFrame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.contentView = hostingView
            window.backgroundColor = NSColor(white: 0.1, alpha: 0.95)
            window.isOpaque = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.titlebarAppearsTransparent = true
            window.hasShadow = false
            window.makeKeyAndOrderFront(nil)

            windows.append(window)
        }
    }

    private func recreateWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
        createWindowsForAllScreens()
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

        // Update all windows
        for window in windows {
            window.contentView = NSHostingView(rootView: contentView)
        }
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
