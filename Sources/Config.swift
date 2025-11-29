import Foundation
import TOMLKit
import SwiftUI

enum BarPosition: String {
    case top
    case bottom
    case left
    case right
}

struct ColorConfig {
    let background: Color
    let workspaceActiveBackground: Color
    let workspaceHoverBackground: Color
    let workspaceDefaultBackground: Color
    let textActive: Color
    let textInactive: Color
    let textSecondary: Color
    let textClock: Color
    let fullscreenBadgeBackground: Color
    let fullscreenBadgeSymbol: Color

    static let `default` = ColorConfig(
        background: Color(white: 0.1, opacity: 0.95),
        workspaceActiveBackground: Color.blue.opacity(0.6),
        workspaceHoverBackground: Color.white.opacity(0.2),
        workspaceDefaultBackground: Color.white.opacity(0.1),
        textActive: .white,
        textInactive: .white.opacity(0.7),
        textSecondary: .white.opacity(0.5),
        textClock: .white.opacity(0.9),
        fullscreenBadgeBackground: .green,
        fullscreenBadgeSymbol: .white
    )

    static func parseColor(_ hex: String) -> Color? {
        // Parse #RRGGBB, #RRGGBBAA, #RGB formats
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: Double

        switch length {
        case 3: // #RGB
            r = Double((rgb >> 8) & 0xF) / 15.0
            g = Double((rgb >> 4) & 0xF) / 15.0
            b = Double(rgb & 0xF) / 15.0
            a = 1.0
        case 6: // #RRGGBB
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            a = 1.0
        case 8: // #RRGGBBAA
            r = Double((rgb >> 24) & 0xFF) / 255.0
            g = Double((rgb >> 16) & 0xFF) / 255.0
            b = Double((rgb >> 8) & 0xFF) / 255.0
            a = Double(rgb & 0xFF) / 255.0
        default:
            return nil
        }

        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

struct Config {
    let aerospacePath: String
    let barPosition: BarPosition
    let barSize: CGFloat
    let pollInterval: Int  // in milliseconds
    let colors: ColorConfig
    let components: [ComponentInstance]

    static let `default` = Config(
        aerospacePath: "/usr/local/bin/hyprspace",
        barPosition: .top,
        barSize: 25,
        pollInterval: 300,  // 300ms default
        colors: .default,
        components: defaultComponents()
    )

    /// Default components (workspaces on left, clock on right)
    private static func defaultComponents() -> [ComponentInstance] {
        return [
            ComponentInstance(
                type: .workspaces,
                centering: .left,
                padding: ComponentPadding(top: 0, right: 0, bottom: 0, left: 8),
                order: 0
            ),
            ComponentInstance(
                type: .clock,
                centering: .right,
                padding: ComponentPadding(top: 0, right: 8, bottom: 0, left: 0),
                order: 1
            )
        ]
    }

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

        // Read aerospace-poll-interval setting, fall back to default if not specified
        // Validate it's > 100ms to prevent excessive polling
        let pollInterval: Int
        if let intervalValue = table["aerospace-poll-interval"]?.int {
            if intervalValue > 100 {
                pollInterval = intervalValue
            } else {
                print("Warning: aerospace-poll-interval must be > 100ms, using default of 300ms")
                pollInterval = Config.default.pollInterval
            }
        } else {
            pollInterval = Config.default.pollInterval
        }

        // Read [colors] section if present
        let colors: ColorConfig
        if let colorsTable = table["colors"]?.table {
            colors = ColorConfig(
                background: colorsTable["background"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.background,
                workspaceActiveBackground: colorsTable["workspace-active-background"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.workspaceActiveBackground,
                workspaceHoverBackground: colorsTable["workspace-hover-background"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.workspaceHoverBackground,
                workspaceDefaultBackground: colorsTable["workspace-default-background"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.workspaceDefaultBackground,
                textActive: colorsTable["text-active"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.textActive,
                textInactive: colorsTable["text-inactive"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.textInactive,
                textSecondary: colorsTable["text-secondary"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.textSecondary,
                textClock: colorsTable["text-clock"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.textClock,
                fullscreenBadgeBackground: colorsTable["fullscreen-badge-background"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.fullscreenBadgeBackground,
                fullscreenBadgeSymbol: colorsTable["fullscreen-badge-symbol"]?.string.flatMap(ColorConfig.parseColor) ?? ColorConfig.default.fullscreenBadgeSymbol
            )
        } else {
            colors = .default
        }

        // Read [components] section - REQUIRED
        let components: [ComponentInstance]
        guard let componentsTable = table["components"]?.table else {
            print(ComponentConfigError.missingComponentsSection.description)
            exit(1)
        }

        components = parseComponents(from: componentsTable)

        return Config(aerospacePath: aerospacePath, barPosition: barPosition, barSize: barSize, pollInterval: pollInterval, colors: colors, components: components)
    }

    /// Parse components from [components] table
    private static func parseComponents(from table: TOMLTable) -> [ComponentInstance] {
        var instances: [ComponentInstance] = []

        // Iterate through component sections in order (preserves TOML order)
        for (index, key) in table.keys.enumerated() {
            // Validate component type
            guard let componentType = ComponentType(rawValue: key) else {
                print(ComponentConfigError.invalidComponent(key).description)
                exit(1)
            }

            guard let componentTable = table[key]?.table else {
                continue
            }

            // Centering is REQUIRED
            guard let centeringString = componentTable["centering"]?.string,
                  let centering = ComponentCentering(rawValue: centeringString) else {
                print(ComponentConfigError.missingCentering(key).description)
                exit(1)
            }

            // Padding is optional (defaults to zero)
            let padding: ComponentPadding
            if let paddingString = componentTable["padding"]?.string {
                do {
                    padding = try ComponentPadding(from: paddingString)
                } catch {
                    print(ComponentConfigError.invalidPadding(paddingString).description)
                    exit(1)
                }
            } else {
                padding = .zero
            }

            instances.append(ComponentInstance(
                type: componentType,
                centering: centering,
                padding: padding,
                order: index
            ))
        }

        return instances
    }
}
