import Foundation

class AerospaceClient {
    private let aerospaceCommand: String
    private let config: Config

    init(config: Config) {
        self.config = config
        self.aerospaceCommand = config.aerospacePath
    }

    /// Get list of non-hidden workspaces
    func getWorkspaces() -> [String] {
        let output = runCommand(arguments: ["list-workspaces", "--all"])
        return output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Get current workspace
    func getCurrentWorkspace() -> String? {
        let output = runCommand(arguments: ["list-workspaces", "--focused"])
        let workspace = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return workspace.isEmpty ? nil : workspace
    }

    /// Switch to a specific workspace
    func switchToWorkspace(_ workspace: String) {
        _ = runCommand(arguments: ["workspace", workspace])
    }

    /// Get current mode from aerospace
    /// Returns nil if mode-command is not configured
    /// Returns current mode string if successful (Aerospace always has an active mode)
    func getCurrentMode() -> String? {
        // If mode command not configured, return nil immediately
        guard let modeCommand = config.modeCommand else {
            DebugLogger.log("Mode command not configured, skipping mode query")
            return nil
        }

        DebugLogger.log("Querying current mode with command: \(modeCommand)")

        // Split command into arguments (e.g., "list-modes --current" -> ["list-modes", "--current"])
        let arguments = modeCommand.split(separator: " ").map { String($0) }

        guard !arguments.isEmpty else {
            DebugLogger.log("Mode command is empty after parsing")
            return nil
        }

        let output = runCommand(arguments: arguments)
        let mode = output.trimmingCharacters(in: .whitespacesAndNewlines)

        if mode.isEmpty {
            let errorMsg = "WARNING: Mode query returned empty result. Command: \(aerospaceCommand) \(arguments.joined(separator: " "))"
            DebugLogger.log(errorMsg)
            fputs(errorMsg + "\n", stderr)
            // Return "Error" to indicate failure
            return "Error"
        }

        DebugLogger.log("Current mode: \(mode)")
        return mode
    }

    /// Get apps grouped by workspace with fullscreen status
    /// Returns a dictionary mapping workspace names to arrays of AppInfo
    func getAppsPerWorkspace() -> [String: [AppInfo]] {
        let output = runCommand(arguments: ["list-windows", "--all", "--format", "%{workspace}|%{app-name}|%{window-is-fullscreen}"])

        var appsPerWorkspace: [String: [AppInfo]] = [:]
        var fullscreenStatus: [String: [String: Bool]] = [:] // workspace -> appName -> isFullscreen

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

            // Track fullscreen status - if ANY window of an app is fullscreen, mark the app as fullscreen
            if fullscreenStatus[workspace] == nil {
                fullscreenStatus[workspace] = [:]
            }
            if fullscreenStatus[workspace]![appName] == nil {
                fullscreenStatus[workspace]![appName] = isFullscreen
            } else {
                // If any window is fullscreen, mark app as fullscreen
                fullscreenStatus[workspace]![appName] = fullscreenStatus[workspace]![appName]! || isFullscreen
            }
        }

        // Convert to AppInfo array
        for (workspace, apps) in fullscreenStatus {
            appsPerWorkspace[workspace] = apps.map { appName, isFullscreen in
                AppInfo(name: appName, isFullscreen: isFullscreen)
            }.sorted { $0.name < $1.name }
        }

        return appsPerWorkspace
    }

    /// Run aerospace command and return output
    private func runCommand(arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: aerospaceCommand)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("Error running aerospace command: \(error)")
            return ""
        }
    }
}
