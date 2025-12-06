import Foundation
import TOMLKit

/// Central registry for all available widgets
class WidgetRegistry {
    static let shared = WidgetRegistry()

    private var widgets: [String: MenuBarWidget.Type] = [:]

    private init() {
        // Register all built-in widgets
        register(WorkspacesWidget.self)
        register(SpacerWidget.self)
        register(ModeWidget.self)
        register(AudioWidget.self)
        register(ClockWidget.self)
    }

    /// Register a widget type
    func register(_ widgetType: MenuBarWidget.Type) {
        widgets[widgetType.identifier] = widgetType
    }

    /// Create a widget instance from configuration
    func createWidget(
        identifier: String,
        parameterTable: TOMLTable?
    ) -> MenuBarWidget? {
        guard let widgetType = widgets[identifier] else {
            print("Warning: Unknown widget identifier '\(identifier)'")
            return nil
        }

        // Parse parameters if widget supports them
        let parameters: WidgetParameters
        if let parameterizedType = widgetType as? ParameterizedWidget.Type {
            parameters = WidgetParameterParser.parse(
                table: parameterTable,
                definitions: parameterizedType.parameterDefinitions
            )
        } else {
            parameters = widgetType.defaultParameters
        }

        return widgetType.init(parameters: parameters)
    }

    /// Create widgets from widget config
    func createWidgets(from config: WidgetConfig) -> [MenuBarWidget] {
        var instances: [MenuBarWidget] = []
        var seen = Set<String>()

        for identifier in config.order {
            // Skip duplicates
            guard !seen.contains(identifier) else {
                print("Warning: Duplicate widget '\(identifier)' in config, ignoring")
                continue
            }
            seen.insert(identifier)

            // Create widget instance
            if let widget = createWidget(
                identifier: identifier,
                parameterTable: config.parameters[identifier]
            ) {
                instances.append(widget)
            }
        }

        return instances
    }
}
