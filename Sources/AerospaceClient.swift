import Foundation

class AerospaceClient {
    private let aerospaceCommand = "/usr/local/bin/hyprspace"

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
