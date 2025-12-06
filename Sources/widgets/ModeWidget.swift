import SwiftUI

/// Mode indicator widget showing current Aerospace keybind mode
struct ModeWidget: ParameterizedWidget {
    static let identifier = "mode"
    static let displayName = "Mode Indicator"

    static let parameterDefinitions: [WidgetParameterDefinition] = [
        WidgetParameterDefinition(
            key: "font-size-horizontal",
            type: .int,
            defaultValue: 11,
            description: "Font size when bar is horizontal"
        ),
        WidgetParameterDefinition(
            key: "font-size-vertical",
            type: .int,
            defaultValue: 8,
            description: "Font size when bar is vertical"
        )
    ]

    static var defaultParameters: WidgetParameters {
        WidgetParameterParser.parse(table: nil, definitions: parameterDefinitions)
    }

    private let parameters: WidgetParameters

    init(parameters: WidgetParameters) {
        self.parameters = parameters
    }

    func render(manager: MenuBarManager, isVertical: Bool, colors: ColorConfig) -> AnyView {
        let fontSize = isVertical
            ? parameters.getInt("font-size-vertical", default: 8)
            : parameters.getInt("font-size-horizontal", default: 11)

        let content = Group {
            if let mode = manager.currentMode {
                Text(mode)
                    .font(.system(size: CGFloat(fontSize), weight: .medium))
                    .foregroundColor(colors.textInactive)
                    .padding(isVertical ? .bottom : .trailing, 4)
            }
        }

        return AnyView(content)
    }
}
