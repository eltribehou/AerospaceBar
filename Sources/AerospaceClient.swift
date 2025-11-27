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
