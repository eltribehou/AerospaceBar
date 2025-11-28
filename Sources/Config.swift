import Foundation
import TOMLKit

enum BarPosition: String {
    case top
    case bottom
    case left
    case right
}

struct Config {
    let aerospacePath: String
    let barPosition: BarPosition
    let barSize: CGFloat

    static let `default` = Config(
        aerospacePath: "/usr/local/bin/hyprspace",
        barPosition: .top,
        barSize: 25
    )

    static func defaultBarSize(for position: BarPosition) -> CGFloat {
        switch position {
        case .top, .bottom:
            return 25
        case .left, .right:
            return 30
        }
    }

    static func load() -> Config {
        // Try reading from possible config file locations
        let possiblePaths = [
            NSString(string: "~/.aerospacebar.toml").expandingTildeInPath,
            NSString(string: "~/.config/aerospacebar/aerospacebar.toml").expandingTildeInPath
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                if let config = try? loadFromFile(path: path) {
                    return config
                }
            }
        }

        // Return default if no config file found
        return .default
    }

    private static func loadFromFile(path: String) throws -> Config {
        let fileURL = URL(fileURLWithPath: path)
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let table = try TOMLTable(string: contents)

        // Read aerospace-path setting, fall back to default if not specified
        let aerospacePath: String
        if let configuredPath = table["aerospace-path"]?.string {
            aerospacePath = NSString(string: configuredPath).expandingTildeInPath
        } else {
            aerospacePath = Config.default.aerospacePath
        }

        // Read bar-position setting, fall back to default if not specified
        let barPosition: BarPosition
        if let positionString = table["bar-position"]?.string,
           let position = BarPosition(rawValue: positionString) {
            barPosition = position
        } else {
            barPosition = Config.default.barPosition
        }

        // Read bar-size setting, fall back to position-specific default if not specified
        let barSize: CGFloat
        if let sizeValue = table["bar-size"]?.int {
            barSize = CGFloat(sizeValue)
        } else if let sizeValue = table["bar-size"]?.double {
            barSize = CGFloat(sizeValue)
        } else {
            barSize = Config.defaultBarSize(for: barPosition)
        }

        return Config(aerospacePath: aerospacePath, barPosition: barPosition, barSize: barSize)
    }
}
