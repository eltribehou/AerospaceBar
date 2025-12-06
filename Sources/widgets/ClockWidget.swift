import SwiftUI

/// Clock widget displaying current time
struct ClockWidget: ParameterizedWidget {
    static let identifier = "clock"
    static let displayName = "Clock"

    static let parameterDefinitions: [WidgetParameterDefinition] = [
        WidgetParameterDefinition(
            key: "format",
            type: .string,
            defaultValue: "HH:mm",
            description: "Time format (DateFormatter format string)"
        ),
        WidgetParameterDefinition(
            key: "font-size-horizontal",
            type: .int,
            defaultValue: 12,
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
        let format = parameters.getString("format", default: "HH:mm")
        let fontSize = isVertical
            ? parameters.getInt("font-size-vertical", default: 8)
            : parameters.getInt("font-size-horizontal", default: 12)

        let formatter = DateFormatter()
        formatter.dateFormat = format
        let timeString = formatter.string(from: manager.currentTime)

        let content = Text(timeString)
            .font(.system(size: CGFloat(fontSize), weight: .regular))
            .foregroundColor(colors.textClock)

        if !isVertical {
            return AnyView(content.padding(.trailing, 8))
        } else {
            return AnyView(content.padding(.bottom, 8))
        }
    }
}
