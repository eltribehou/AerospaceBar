import AppKit

class AppIconHelper {
    static let shared = AppIconHelper()

    private var iconCache: [String: NSImage] = [:]

    /// Get icon for an app by name
    func getIcon(forAppName appName: String) -> NSImage? {
        // Check cache first
        if let cached = iconCache[appName] {
            return cached
        }

        // Try to find the app and get its icon
        if let icon = findAndLoadIcon(appName: appName) {
            iconCache[appName] = icon
            return icon
        }

        return nil
    }

    private func findAndLoadIcon(appName: String) -> NSImage? {
        let workspace = NSWorkspace.shared

        // Strategy 1: Try to find the app in common locations
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app",
            "/System/Applications/Utilities/\(appName).app",
            "~/Applications/\(appName).app".expandingTildeInPath,
            "~/Applications/Chrome Apps.localized/\(appName).app".expandingTildeInPath
        ]

        for appPath in appPaths {
            if FileManager.default.fileExists(atPath: appPath) {
                return workspace.icon(forFile: appPath)
            }
        }

        // Strategy 2: Search through running applications
        for app in workspace.runningApplications {
            if let localizedName = app.localizedName,
               localizedName == appName {
                return app.icon
            }
        }

        // Strategy 3: Try URL scheme (e.g., com.apple.Safari)
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.\(appName)") {
            return workspace.icon(forFile: url.path)
        }

        // Strategy 4: Try common bundle ID patterns
        let bundlePatterns = [
            "com.apple.\(appName.lowercased())",
            "com.\(appName.lowercased()).\(appName.lowercased())",
            "org.\(appName.lowercased()).\(appName.lowercased())"
        ]

        for bundleId in bundlePatterns {
            if let url = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                return workspace.icon(forFile: url.path)
            }
        }

        return nil
    }
}

extension String {
    var expandingTildeInPath: String {
        return NSString(string: self).expandingTildeInPath
    }
}
