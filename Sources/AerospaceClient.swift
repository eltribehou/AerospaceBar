import Foundation

class AerospaceClient {
    private let aerospaceCommand: String
    private let config: Config
    private let executionQueue = DispatchQueue(
        label: "com.aerospacebar.aerospace-client",
        qos: .userInitiated,
        attributes: .concurrent
    )

    init(config: Config) {
        self.config = config
        self.aerospaceCommand = config.aerospacePath
    }

    /// Get list of non-hidden workspaces (async)
    func getWorkspaces(completion: @escaping ([String]) -> Void) {
        runCommand(arguments: ["list-workspaces", "--all"]) { output in
            let workspaces = output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            completion(workspaces)
        }
    }

    /// Get current workspace (async)
    func getCurrentWorkspace(completion: @escaping (String?) -> Void) {
        runCommand(arguments: ["list-workspaces", "--focused"]) { output in
            let workspace = output.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(workspace.isEmpty ? nil : workspace)
        }
    }

    /// Switch to a specific workspace (async)
    func switchToWorkspace(_ workspace: String, completion: @escaping () -> Void) {
        runCommand(arguments: ["workspace", workspace]) { _ in
            completion()
        }
    }

    /// Get current mode from aerospace (async)
    /// Returns nil if mode-command is not configured
    /// Returns current mode string if successful (Aerospace always has an active mode)
    func getCurrentMode(completion: @escaping (String?) -> Void) {
        // If mode command not configured, return nil immediately
        guard let modeCommand = config.modeCommand else {
            DebugLogger.log("Mode command not configured, skipping mode query")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        DebugLogger.log("Querying current mode with command: \(modeCommand)")

        // Split command into arguments (e.g., "list-modes --current" -> ["list-modes", "--current"])
        let arguments = modeCommand.split(separator: " ").map { String($0) }

        guard !arguments.isEmpty else {
            DebugLogger.log("Mode command is empty after parsing")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        runCommand(arguments: arguments) { [weak self] output in
            guard let self = self else {
                completion(nil)
                return
            }

            let mode = output.trimmingCharacters(in: .whitespacesAndNewlines)

            if mode.isEmpty {
                let errorMsg = "WARNING: Mode query returned empty result. Command: \(self.aerospaceCommand) \(arguments.joined(separator: " "))"
                DebugLogger.log(errorMsg)
                fputs(errorMsg + "\n", stderr)
                // Return "Error" to indicate failure
                completion("Error")
                return
            }

            DebugLogger.log("Current mode: \(mode)")
            completion(mode)
        }
    }

    /// Get apps grouped by workspace with fullscreen status and window counts (async)
    /// Returns a dictionary mapping workspace names to arrays of AppInfo
    func getAppsPerWorkspace(completion: @escaping ([String: [AppInfo]]) -> Void) {
        runCommand(arguments: ["list-windows", "--all", "--format", "%{workspace}|%{app-name}|%{window-is-fullscreen}"]) { output in
            // runCommand already dispatches to main thread, so we're on main thread here
            let result = self.parseAppsPerWorkspace(output: output)
            completion(result)
        }
    }

    /// Parse apps per workspace data (runs on background queue)
    private func parseAppsPerWorkspace(output: String) -> [String: [AppInfo]] {
        var appsPerWorkspace: [String: [AppInfo]] = [:]
        var fullscreenStatus: [String: [String: Bool]] = [:] // workspace -> appName -> isFullscreen
        var windowCounts: [String: [String: Int]] = [:] // workspace -> appName -> windowCount

        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            let components = line.split(separator: "|").map { String($0) }
            guard components.count == 3 else { continue }

            let workspace = components[0]
            let appName = components[1]
            let isFullscreenStr = components[2].lowercased()
            let isFullscreen = (isFullscreenStr == "true" || isFullscreenStr == "yes" || isFullscreenStr == "1")

            // Initialize dictionaries if needed
            if fullscreenStatus[workspace] == nil {
                fullscreenStatus[workspace] = [:]
                windowCounts[workspace] = [:]
            }

            // Track fullscreen status - if ANY window of an app is fullscreen, mark the app as fullscreen
            if fullscreenStatus[workspace]![appName] == nil {
                fullscreenStatus[workspace]![appName] = isFullscreen
                windowCounts[workspace]![appName] = 1
            } else {
                // If any window is fullscreen, mark app as fullscreen
                fullscreenStatus[workspace]![appName] = fullscreenStatus[workspace]![appName]! || isFullscreen
                // Increment window count
                windowCounts[workspace]![appName]! += 1
            }
        }

        // Convert to AppInfo array
        for (workspace, apps) in fullscreenStatus {
            appsPerWorkspace[workspace] = apps.map { appName, isFullscreen in
                let count = windowCounts[workspace]?[appName] ?? 1
                return AppInfo(name: appName, isFullscreen: isFullscreen, windowCount: count)
            }.sorted { $0.name < $1.name }
        }

        return appsPerWorkspace
    }

    /// Run aerospace command and return output (async)
    /// Executes on background queue, calls completion on main queue
    private func runCommand(arguments: [String], completion: @escaping (String) -> Void) {
        executionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion("")
                }
                return
            }

            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: self.aerospaceCommand)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            // Create timeout timer
            var timedOut = false
            let timeout = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                    timedOut = true
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0, execute: timeout)

            do {
                try process.run()
                process.waitUntilExit()  // Now blocks BACKGROUND thread only
                timeout.cancel()  // Cancel timeout if completed

                if timedOut {
                    print("Aerospace command timed out: \(arguments)")
                    DispatchQueue.main.async {
                        completion("")
                    }
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                // Call completion on main queue
                DispatchQueue.main.async {
                    completion(output)
                }
            } catch {
                timeout.cancel()
                print("Error running aerospace command: \(error)")
                DispatchQueue.main.async {
                    completion("")
                }
            }
        }
    }
}
