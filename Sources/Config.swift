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

struct WidgetConfig {
    let widgets: [(type: String, params: TOMLTable)]

    // Computed property for backwards compatibility with existing code
    var order: [String] {
        widgets.map { $0.type }
    }

    // Computed property for backwards compatibility with existing code
    var parameters: [String: TOMLTable] {
        var dict: [String: TOMLTable] = [:]
        for widget in widgets {
            dict[widget.type] = widget.params
        }
        return dict
    }

    static let `default` = WidgetConfig(widgets: [
        (type: "workspaces", params: TOMLTable()),
        (type: "spacer", params: TOMLTable()),
        (type: "mode", params: TOMLTable()),
        (type: "audio", params: TOMLTable()),
        (type: "clock", params: TOMLTable())
    ])
}

struct Config {
    let aerospacePath: String
    let barPosition: BarPosition
    let barSize: CGFloat
    let barOpacity: Double  // 0.0 (transparent) to 1.0 (opaque)
    let debounceInterval: Int  // in milliseconds
    let modeCommand: String?  // Optional command to get current mode (e.g., "list-modes --current")
    let showWindowCount: Bool  // Show window count badge on app icons when > 1 window
    let colors: ColorConfig
    let widgets: WidgetConfig

    static let `default` = Config(
        aerospacePath: "/usr/local/bin/hyprspace",
        barPosition: .top,
        barSize: 25,
        barOpacity: 1.0,  // Fully opaque by default
        debounceInterval: 150,  // 150ms default - balances responsiveness and efficiency
        modeCommand: nil,  // Disabled by default
        showWindowCount: true,  // Show window count by default
        colors: .default,
        widgets: .default
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
                print("[CONFIG] Found config file at: \(path)")
                DebugLogger.log("Found config file at: \(path)")
                if let config = try? loadFromFile(path: path) {
                    print("[CONFIG] Loaded - position: \(config.barPosition), opacity: \(config.barOpacity), mode-command: \(config.modeCommand ?? "nil")")
                    DebugLogger.log("Loaded config - position: \(config.barPosition), opacity: \(config.barOpacity), mode-command: \(config.modeCommand ?? "nil")")
                    return config
                } else {
                    print("[CONFIG] Failed to parse config file at: \(path)")
                    DebugLogger.log("Failed to parse config file at: \(path)")
                }
            }
        }

        // Return default if no config file found
        print("[CONFIG] No config file found, using defaults")

        // Return default if no config file found
        DebugLogger.log("No config file found, using defaults")
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

        // Read bar-opacity setting, fall back to default (1.0) if not specified
        // Clamp to valid range [0.0, 1.0]
        let barOpacity: Double
        if let opacityValue = table["bar-opacity"]?.double {
            barOpacity = max(0.0, min(1.0, opacityValue))
        } else {
            barOpacity = Config.default.barOpacity
        }

        // Read refresh-debounce-interval setting, fall back to default if not specified
        // Validate it's >= 50ms to prevent excessive refresh rates
        let debounceInterval: Int
        if let intervalValue = table["refresh-debounce-interval"]?.int {
            if intervalValue >= 50 {
                debounceInterval = intervalValue
            } else {
                print("Warning: refresh-debounce-interval must be >= 50ms, using default of 150ms")
                debounceInterval = Config.default.debounceInterval
            }
        } else {
            debounceInterval = Config.default.debounceInterval
        }

        // Read mode-command setting (optional)
        // Full command with parameters to get current mode (e.g., "list-modes --current")
        let modeCommand: String? = table["mode-command"]?.string

        // Read show-window-count setting, fall back to default (true) if not specified
        let showWindowCount: Bool
        if let showWindowCountValue = table["show-window-count"]?.bool {
            showWindowCount = showWindowCountValue
        } else {
            showWindowCount = Config.default.showWindowCount
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

        // Read [[widget]] array of tables if present
        let widgets: WidgetConfig
        if let widgetsArray = table["widget"]?.array {
            var widgetsList: [(type: String, params: TOMLTable)] = []

            for widgetValue in widgetsArray {
                if let widgetTable = widgetValue.table {
                    // Extract widget name (required field)
                    if let widgetType = widgetTable["name"]?.string {
                        widgetsList.append((type: widgetType, params: widgetTable))
                    } else {
                        print("Warning: Widget entry missing 'name' field, skipping")
                    }
                }
            }

            if widgetsList.isEmpty {
                print("Warning: No valid widgets found, using defaults")
                widgets = .default
            } else {
                widgets = WidgetConfig(widgets: widgetsList)
            }
        } else {
            // No [[widget]] section, use defaults
            widgets = .default
        }

        return Config(aerospacePath: aerospacePath, barPosition: barPosition, barSize: barSize, barOpacity: barOpacity, debounceInterval: debounceInterval, modeCommand: modeCommand, showWindowCount: showWindowCount, colors: colors, widgets: widgets)
    }
}
