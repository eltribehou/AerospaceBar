import Foundation
import TOMLKit
import SwiftUI
import AppKit

// MARK: - Conditional Configuration System

/// Context object providing all information needed for rule matching
struct MatchContext {
    let screen: NSScreen

    // Current criteria
    var displayName: String {
        screen.localizedName
    }

    // Future criteria can be added here:
    // var screenRatio: String { calculateRatio(screen.frame.size) }
    // var hostname: String { ProcessInfo.processInfo.hostName }
    // var isBuiltin: Bool { ... }
    // var hasNotch: Bool { screen.frame.maxY - screen.visibleFrame.maxY > 24 }
}

/// Protocol for matching criteria
protocol MatchCriterion {
    func matches(context: MatchContext) -> Bool
}

/// Matches display name using regex pattern
struct DisplayNameCriterion: MatchCriterion {
    let pattern: String

    func matches(context: MatchContext) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(location: 0, length: context.displayName.utf16.count)
        return regex.firstMatch(in: context.displayName, range: range) != nil
    }
}

/// A rule with optional criteria and a value
struct ConditionalRule<T> {
    let criteria: [MatchCriterion]
    let value: T

    func matches(context: MatchContext) -> Bool {
        // Empty criteria = always matches (fallback rule)
        if criteria.isEmpty {
            return true
        }

        // ALL criteria must match (AND logic)
        return criteria.allSatisfy { $0.matches(context: context) }
    }
}

/// Generic wrapper for conditional config values
struct ConditionalConfig<T> {
    let rules: [ConditionalRule<T>]

    func resolve(for screen: NSScreen) -> T {
        let context = MatchContext(screen: screen)

        for rule in rules {
            if rule.matches(context: context) {
                return rule.value
            }
        }

        // Fallback: return first rule's value (should always have at least one rule)
        return rules.first!.value
    }

    // Simple constructor for backward compatibility
    init(value: T) {
        self.rules = [ConditionalRule(criteria: [], value: value)]
    }

    // Constructor with conditional rules
    init(rules: [ConditionalRule<T>]) {
        self.rules = rules
    }
}

// MARK: - Config Parsing Helpers

/// Parse criteria fields from TOML into MatchCriterion objects
func parseCriteria(from fields: TOMLTable) -> [MatchCriterion] {
    var criteria: [MatchCriterion] = []

    if let displayPattern = fields["display"]?.string {
        criteria.append(DisplayNameCriterion(pattern: displayPattern))
    }

    // Future criteria parsing can be added here:
    // if let screenRatio = fields["screen-ratio"]?.string {
    //     criteria.append(ScreenRatioCriterion(ratio: screenRatio))
    // }
    // if let hostnamePattern = fields["hostname"]?.string {
    //     criteria.append(HostnameCriterion(pattern: hostnamePattern))
    // }

    return criteria
}

/// Generic parser for conditional config values
/// Takes a TOML value and a type-specific parser function
/// Returns ConditionalConfig with rules or nil if parsing failed
func parseConditionalConfig<T>(
    from tomlValue: TOMLValueConvertible?,
    parser: (TOMLValueConvertible) -> T?
) -> ConditionalConfig<T>? {
    guard let tomlValue = tomlValue else {
        return nil
    }

    // Try simple scalar value first (backward compatible)
    if let simpleValue = parser(tomlValue) {
        return ConditionalConfig(value: simpleValue)
    }

    // Try conditional format with rules array
    if let array = tomlValue.array {
        var rules: [ConditionalRule<T>] = []

        for item in array {
            if let simpleValue = parser(item) {
                // No criteria = default/fallback rule
                rules.append(ConditionalRule(criteria: [], value: simpleValue))
            } else if let table = item.table,
                      let rawValue = table["value"],
                      let value = parser(rawValue) {
                // Rule with criteria
                // Build criteria fields (all fields except "value")
                var criteriaFields = TOMLTable()
                for (key, val) in table where key != "value" {
                    criteriaFields[key] = val  // swiftlint:disable:this no_direct_assignment
                }

                let criteria = parseCriteria(from: criteriaFields)
                rules.append(ConditionalRule(criteria: criteria, value: value))
            } else {
                print("Warning: Invalid conditional config rule, skipping")
            }
        }

        if !rules.isEmpty {
            return ConditionalConfig(rules: rules)
        }
    }

    return nil
}

// MARK: - Enums

enum BarPosition: String {
    case top
    case bottom
    case left
    case right
}

// MARK: - Color Configuration

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
    let barPosition: ConditionalConfig<BarPosition>
    let barSize: ConditionalConfig<CGFloat>
    let barOpacity: Double  // 0.0 (transparent) to 1.0 (opaque)
    let debounceInterval: Int  // in milliseconds
    let modeCommand: String?  // Optional command to get current mode (e.g., "list-modes --current")
    let showWindowCount: Bool  // Show window count badge on app icons when > 1 window
    let hideOnFullscreenApps: Bool  // Hide menubar when apps enter native fullscreen
    let allowSystemMenubarOnTop: Bool  // Allow macOS menubar on top of aerospacebar
    let colors: ColorConfig
    let widgets: WidgetConfig

    static let `default` = Config(
        aerospacePath: "/usr/local/bin/hyprspace",
        barPosition: ConditionalConfig(value: .top),
        barSize: ConditionalConfig(value: 25),
        barOpacity: 1.0,  // Fully opaque by default
        debounceInterval: 150,  // 150ms default - balances responsiveness and efficiency
        modeCommand: nil,  // Disabled by default
        showWindowCount: true,  // Show window count by default
        hideOnFullscreenApps: true,  // Hide on fullscreen by default
        allowSystemMenubarOnTop: false,  // Keep at status bar level by default
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
                    let positionDesc = config.barPosition.rules.count == 1 && config.barPosition.rules.first?.criteria.isEmpty == true
                        ? config.barPosition.rules.first?.value.rawValue ?? "unknown"
                        : "conditional (\(config.barPosition.rules.count) rules)"
                    let sizeDesc = config.barSize.rules.count == 1 && config.barSize.rules.first?.criteria.isEmpty == true
                        ? String(format: "%.0f", config.barSize.rules.first?.value ?? 0)
                        : "conditional (\(config.barSize.rules.count) rules)"
                    print("[CONFIG] Loaded - position: \(positionDesc), size: \(sizeDesc), opacity: \(config.barOpacity), mode-command: \(config.modeCommand ?? "nil")")
                    DebugLogger.log("Loaded config - position: \(positionDesc), size: \(sizeDesc), opacity: \(config.barOpacity), mode-command: \(config.modeCommand ?? "nil")")
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
        // Supports two formats:
        // 1. Simple string: bar-position = "top"
        // 2. Conditional array: bar-position = [{ display = "^Built-in.*$", value = "top" }, "right"]
        let barPosition = parseConditionalConfig(
            from: table["bar-position"],
            parser: { value in
                if let str = value.string {
                    return BarPosition(rawValue: str)
                }
                return nil
            }
        ) ?? Config.default.barPosition

        // Read bar-size setting, fall back to position-specific default if not specified
        // Supports two formats:
        // 1. Simple number: bar-size = 30
        // 2. Conditional array: bar-size = [{ display = "^Built-in.*$", value = 32 }, 25]
        let barSize = parseConditionalConfig(
            from: table["bar-size"],
            parser: { value in
                if let int = value.int {
                    return CGFloat(int)
                } else if let double = value.double {
                    return CGFloat(double)
                }
                return nil
            }
        ) ?? Config.default.barSize

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

        // Read hide-on-fullscreen-apps setting, fall back to default (true) if not specified
        let hideOnFullscreenApps: Bool
        if let hideOnFullscreenAppsValue = table["hide-on-fullscreen-apps"]?.bool {
            hideOnFullscreenApps = hideOnFullscreenAppsValue
        } else {
            hideOnFullscreenApps = Config.default.hideOnFullscreenApps
        }

        // Read allow-system-menubar-on-top setting, fall back to default (false) if not specified
        let allowSystemMenubarOnTop: Bool
        if let allowValue = table["allow-system-menubar-on-top"]?.bool {
            allowSystemMenubarOnTop = allowValue
        } else {
            allowSystemMenubarOnTop = Config.default.allowSystemMenubarOnTop
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

        return Config(aerospacePath: aerospacePath, barPosition: barPosition, barSize: barSize, barOpacity: barOpacity, debounceInterval: debounceInterval, modeCommand: modeCommand, showWindowCount: showWindowCount, hideOnFullscreenApps: hideOnFullscreenApps, allowSystemMenubarOnTop: allowSystemMenubarOnTop, colors: colors, widgets: widgets)
    }
}
