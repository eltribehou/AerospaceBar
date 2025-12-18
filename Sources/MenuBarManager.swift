import AppKit
import SwiftUI

// Callback function for AXObserver (must be at top level, outside class)
private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notificationName: CFString,
    userData: UnsafeMutableRawPointer?
) {
    guard let userData = userData else { return }

    let manager = Unmanaged<MenuBarManager>.fromOpaque(userData).takeUnretainedValue()

    // Check fullscreen state when window resizes or focus changes
    DispatchQueue.main.async {
        manager.checkAndUpdateMenuBarVisibility()
    }
}

class MenuBarManager: ObservableObject {
    private var window: NSWindow?
    private let aerospaceClient: AerospaceClient
    private let audioClient: AudioClient
    private let config: Config
    @Published var currentBarPosition: BarPosition?  // Track current bar position
    @Published var currentBarSize: CGFloat = 30  // Track current resolved bar size

    // Debounce timers to prevent excessive refresh calls during rapid events
    // Uses trailing-edge debouncing: waits for activity to stop before refreshing
    private var debounceTimer: Timer?
    private var modeDebounceTimer: Timer?

    @Published var workspaces: [String] = []
    @Published var currentWorkspace: String?
    @Published var appsPerWorkspace: [String: [AppInfo]] = [:]
    @Published var currentMode: String?  // Current Aerospace keybind mode (nil if mode-command not configured)
    @Published var currentAudioDevice: AudioDeviceInfo?  // Current audio output device

    private var appObserver: AXObserver?
    private var currentObservedPID: pid_t?

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

        // Listen for display configuration changes (main display change, connect/disconnect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Listen for application switches
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleApplicationDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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

    @objc private func handleScreenParametersChange() {
        guard let screen = NSScreen.main, let window = window else {
            return
        }

        // Resolve position and size for the current main display
        let newPosition = config.barPosition.resolve(for: screen)
        let newSize = config.barSize.resolve(for: screen)

        // Check if position or size changed
        let positionChanged = currentBarPosition != newPosition
        let sizeChanged = abs(currentBarSize - newSize) > 0.01  // Float comparison with epsilon

        if !positionChanged && !sizeChanged {
            return
        }

        // Update position and/or size (triggers SwiftUI re-render via @Published)
        if positionChanged {
            currentBarPosition = newPosition
        }
        if sizeChanged {
            currentBarSize = newSize
        }

        // Update window frame for new position and/or size
        let newFrame = calculateWindowFrame(for: screen, position: newPosition, size: newSize)
        window.setFrame(newFrame, display: true, animate: false)
    }

    @objc private func handleApplicationDidActivate(_ notification: Notification) {
        // When user switches apps, check if new app's focused window is fullscreen
        checkAndUpdateMenuBarVisibility()

        // Set up AXObserver for the new frontmost app
        setupObserverForFrontmostApp()
    }

    private func setupObserverForFrontmostApp() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return
        }

        let pid = frontmostApp.processIdentifier

        // If we're already observing this app, skip
        if currentObservedPID == pid {
            return
        }

        // Clean up previous observer
        if let observer = appObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            appObserver = nil
        }

        // Create new observer
        var observer: AXObserver?
        let error = AXObserverCreate(pid, axObserverCallback, &observer)

        guard error == .success, let observer = observer else {
            return
        }

        self.appObserver = observer
        self.currentObservedPID = pid

        // Get the frontmost app element
        let appElement = AXUIElementCreateApplication(pid)

        // Register for window resize notifications (includes fullscreen toggle)
        AXObserverAddNotification(
            observer,
            appElement,
            kAXWindowResizedNotification as CFString,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        // Register for focused window change notifications
        AXObserverAddNotification(
            observer,
            appElement,
            kAXFocusedWindowChangedNotification as CFString,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        // Add observer to run loop
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
    }

    fileprivate func checkAndUpdateMenuBarVisibility() {
        let isFullscreen = isFrontmostWindowFullscreen()

        if isFullscreen {
            if window?.isVisible == true {
                window?.orderOut(nil)
            }
        } else {
            if window?.isVisible == false {
                window?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func isFrontmostWindowFullscreen() -> Bool {
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        // Create AXUIElement for the application
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

        // Get the focused window
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard result == .success, let windowElement = focusedWindow else {
            return false
        }

        // Check for AXFullScreen attribute
        var fullscreenValue: AnyObject?
        let fullscreenResult = AXUIElementCopyAttributeValue(
            windowElement as! AXUIElement,
            "AXFullScreen" as CFString,
            &fullscreenValue
        )

        if fullscreenResult == .success, let isFullscreen = fullscreenValue as? Bool {
            return isFullscreen
        }

        return false
    }

    func setup() {
        // Get initial workspaces, mode, and audio (no debouncing on startup - need immediate state)
        DebugLogger.log("App startup - performing initial workspace, mode, and audio refresh")
        refreshWorkspaces()
        refreshMode()
        refreshAudio()

        // Start listening for audio device and volume changes
        audioClient.startListening()

        // Create initial window
        createWindow()

        // Set up observer for current frontmost app
        setupObserverForFrontmostApp()

        // Do initial fullscreen check
        checkAndUpdateMenuBarVisibility()
    }

    private func createWindow() {
        // Get main screen and resolve position
        guard let screen = NSScreen.main else {
            print("Error: No main screen available")
            return
        }

        let resolvedPosition = config.barPosition.resolve(for: screen)
        currentBarPosition = resolvedPosition

        let resolvedSize = config.barSize.resolve(for: screen)
        currentBarSize = resolvedSize

        // Create content view
        let contentView = MenuBarView(
            manager: self,
            barSize: resolvedSize,
            barOpacity: config.barOpacity,
            showWindowCount: config.showWindowCount,
            colors: config.colors,
            widgetConfig: config.widgets,
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        let hostingView = NSHostingView(rootView: contentView)

        // Calculate window frame for the resolved position and size
        let windowFrame = calculateWindowFrame(for: screen, position: resolvedPosition, size: resolvedSize)

        // Create new window
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
    }

    private func calculateWindowFrame(for screen: NSScreen, position: BarPosition, size: CGFloat) -> NSRect {
        switch position {
        case .top:
            // Calculate actual menubar height (accounts for notch on newer Macs)
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            // Use the larger of configured size or menubar height (to accommodate notch)
            let barHeight = max(size, menuBarHeight)
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
                height: size
            )
        case .left:
            return NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: size,
                height: screen.frame.height
            )
        case .right:
            return NSRect(
                x: screen.frame.origin.x + screen.frame.width - size,
                y: screen.frame.origin.y,
                width: size,
                height: screen.frame.height
            )
        }
    }

    func teardown() {
        // Clean up AXObserver
        if let observer = appObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            appObserver = nil
        }
        currentObservedPID = nil

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
            guard let self = self else { return }

            self.currentMode = mode
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
