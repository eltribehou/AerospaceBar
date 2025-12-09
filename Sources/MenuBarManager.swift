import AppKit
import SwiftUI

class MenuBarManager: ObservableObject {
    private var window: NSWindow?
    private let aerospaceClient: AerospaceClient
    private let audioClient: AudioClient
    private let config: Config

    // Debounce timers to prevent excessive refresh calls during rapid events
    // Uses trailing-edge debouncing: waits for activity to stop before refreshing
    private var debounceTimer: Timer?
    private var modeDebounceTimer: Timer?

    @Published var workspaces: [String] = []
    @Published var currentWorkspace: String?
    @Published var appsPerWorkspace: [String: [AppInfo]] = [:]
    @Published var currentTime = Date()
    @Published var currentMode: String?  // Current Aerospace keybind mode (nil if mode-command not configured)
    @Published var currentAudioDevice: AudioDeviceInfo?  // Current audio output device

    init() {
        let config = Config.load()
        self.config = config
        self.aerospaceClient = AerospaceClient(config: config)
        self.audioClient = AudioClient()

        // Set up distributed notification listeners for external refresh requests
        // Use suspensionBehavior: .deliverImmediately to ensure notifications are received
        // even when the app might be considered "inactive"
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self,
            selector: #selector(handleRefreshWindowsNotification),
            name: NSNotification.Name("com.aerospacebar.refreshWindows"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        center.addObserver(
            self,
            selector: #selector(handleRefreshModeNotification),
            name: NSNotification.Name("com.aerospacebar.refreshMode"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        center.addObserver(
            self,
            selector: #selector(handleRefreshAudioNotification),
            name: NSNotification.Name("com.aerospacebar.refreshAudio"),
            object: nil,
            suspensionBehavior: .deliverImmediately
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

    @objc private func handleRefreshModeNotification() {
        // Implement trailing-edge debouncing for mode refresh
        // This prevents excessive CLI calls during rapid mode changes

        DebugLogger.log("Received refresh-mode notification")

        // Cancel any pending mode refresh timer
        if modeDebounceTimer != nil {
            DebugLogger.log("Cancelling pending mode debounce timer")
            modeDebounceTimer?.invalidate()
        }

        // Create new timer that will fire after the debounce interval
        // Convert milliseconds to seconds for Timer
        let debounceSeconds = TimeInterval(config.debounceInterval) / 1000.0

        DebugLogger.log("Starting mode debounce timer (\(config.debounceInterval)ms)")

        modeDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceSeconds, repeats: false) { [weak self] _ in
            // Timer fired - no more events for debounce duration, safe to refresh
            DebugLogger.log("Mode debounce timer fired - executing mode refresh")
            self?.refreshMode()
        }
    }

    @objc private func handleRefreshAudioNotification() {
        // Audio refresh without debouncing - typically called manually after device switch
        DebugLogger.log("Received refresh-audio notification")
        refreshAudio()
    }

    func setup() {
        // Get initial workspaces, mode, and audio (no debouncing on startup - need immediate state)
        DebugLogger.log("App startup - performing initial workspace, mode, and audio refresh")
        refreshWorkspaces()
        refreshMode()
        refreshAudio()

        // Start listening for audio device and volume changes
        audioClient.startListening()

        // Create the menubar window with the manager as observed object
        let contentView = MenuBarView(
            manager: self,
            barPosition: config.barPosition,
            barSize: config.barSize,
            barOpacity: config.barOpacity,
            showWindowCount: config.showWindowCount,
            colors: config.colors,
            widgetConfig: config.widgets,
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
        window?.backgroundColor = .clear  // Let SwiftUI handle the background with opacity
        window?.isOpaque = false
        window?.level = .statusBar  // Higher level to occupy menubar area when system menubar is hidden
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
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
        audioClient.stopListening()
        window?.close()
        window = nil
    }

    private func refreshWorkspaces() {
        DebugLogger.log("Refreshing workspaces - querying Aerospace CLI")

        // Fetch current workspace (async, non-blocking)
        aerospaceClient.getCurrentWorkspace { [weak self] workspace in
            guard let self = self else { return }

            // Fetch apps per workspace (async, non-blocking)
            self.aerospaceClient.getAppsPerWorkspace { apps in
                // Already on main thread via completion
                var updatedApps = apps

                // Always include current workspace, even if empty
                if let current = workspace, updatedApps[current] == nil {
                    updatedApps[current] = []
                }

                // Update @Published properties (on main thread)
                self.currentWorkspace = workspace
                self.appsPerWorkspace = updatedApps
                self.workspaces = Array(updatedApps.keys)
                    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

                DebugLogger.log("Refresh complete - current workspace: \(workspace ?? "none"), \(self.workspaces.count) workspaces total")
            }
        }
    }

    private func refreshMode() {
        DebugLogger.log("Refreshing mode - querying Aerospace CLI")

        // Fetch mode (async, non-blocking)
        aerospaceClient.getCurrentMode { [weak self] mode in
            self?.currentMode = mode
            DebugLogger.log("Mode refresh complete - current mode: \(mode ?? "none")")
        }
    }

    private func refreshAudio() {
        DebugLogger.log("Refreshing audio output device")

        currentAudioDevice = audioClient.getCurrentOutputDevice()

        if let device = currentAudioDevice {
            DebugLogger.log("Audio refresh complete - device: \(device.name)")
        } else {
            DebugLogger.log("Audio refresh complete - no device found")
        }
    }

    func switchToWorkspace(_ workspace: String) {
        DebugLogger.log("User clicked workspace '\(workspace)' - switching and refreshing")

        // Switch workspace (async, non-blocking)
        aerospaceClient.switchToWorkspace(workspace) { [weak self] in
            // After switch completes, wait briefly then refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.refreshWorkspaces()  // Now also async
            }
        }
    }
}
