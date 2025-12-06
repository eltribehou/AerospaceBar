import Foundation
import SwiftUI
import TOMLKit

/// Base protocol that all menubar widgets must conform to
protocol MenuBarWidget {
    /// Unique identifier for the widget (used in config parsing)
    static var identifier: String { get }

    /// Human-readable name for the widget
    static var displayName: String { get }

    /// Default parameter values for this widget
    static var defaultParameters: WidgetParameters { get }

    /// Initialize the widget with parsed parameters
    init(parameters: WidgetParameters)

    /// Render the widget view with access to manager state
    /// isVertical indicates bar orientation (true for left/right, false for top/bottom)
    func render(manager: MenuBarManager, isVertical: Bool, colors: ColorConfig) -> AnyView
}

/// Extended protocol for widgets with configurable parameters
protocol ParameterizedWidget: MenuBarWidget {
    /// Define all parameters this widget accepts
    static var parameterDefinitions: [WidgetParameterDefinition] { get }
}

/// Type-safe parameter storage for widgets
struct WidgetParameters {
    private var storage: [String: Any] = [:]

    /// Get a string parameter
    func getString(_ key: String, default defaultValue: String) -> String {
        (storage[key] as? String) ?? defaultValue
    }

    /// Get an integer parameter
    func getInt(_ key: String, default defaultValue: Int) -> Int {
        (storage[key] as? Int) ?? defaultValue
    }

    /// Get a float parameter
    func getFloat(_ key: String, default defaultValue: Float) -> Float {
        (storage[key] as? Float) ?? defaultValue
    }

    /// Get a boolean parameter
    func getBool(_ key: String, default defaultValue: Bool) -> Bool {
        (storage[key] as? Bool) ?? defaultValue
    }

    /// Get a color parameter
    func getColor(_ key: String, default defaultValue: Color) -> Color {
        (storage[key] as? Color) ?? defaultValue
    }

    /// Set a parameter value (used during config parsing)
    mutating func set(_ key: String, value: Any) {
        storage[key] = value
    }
}

/// Parameter type enum
enum WidgetParameterType {
    case string
    case int
    case float
    case bool
    case color
}

/// Parameter definition with type information
struct WidgetParameterDefinition {
    let key: String
    let type: WidgetParameterType
    let defaultValue: Any
    let description: String
}

/// Helper for parsing widget parameters from TOML
struct WidgetParameterParser {
    /// Parse parameters from TOML table for a specific widget
    static func parse(
        table: TOMLTable?,
        definitions: [WidgetParameterDefinition]
    ) -> WidgetParameters {
        var params = WidgetParameters()

        for definition in definitions {
            // Start with default value
            var value: Any = definition.defaultValue

            // Try to override from TOML if present
            if let tomlValue = table?[definition.key] {
                switch definition.type {
                case .string:
                    if let stringValue = tomlValue.string {
                        value = stringValue
                    }
                case .int:
                    if let intValue = tomlValue.int {
                        value = intValue
                    }
                case .float:
                    if let doubleValue = tomlValue.double {
                        value = Float(doubleValue)
                    }
                case .bool:
                    if let boolValue = tomlValue.bool {
                        value = boolValue
                    }
                case .color:
                    if let hexString = tomlValue.string,
                       let color = ColorConfig.parseColor(hexString) {
                        value = color
                    }
                }
            }

            params.set(definition.key, value: value)
        }

        return params
    }
}
