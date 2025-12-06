import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var manager: MenuBarManager
    let barPosition: BarPosition
    let barOpacity: Double
    let colors: ColorConfig
    let widgetConfig: WidgetConfig
    let onQuit: () -> Void

    var body: some View {
        Group {
            switch barPosition {
            case .top, .bottom:
                horizontalLayout
            case .left, .right:
                verticalLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundWithOpacity)
        .contextMenu {
            Button("Quit") {
                onQuit()
            }
        }
    }

    // Replace background color's alpha with barOpacity, preserving RGB
    private var backgroundWithOpacity: Color {
        let nsColor = NSColor(colors.background)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: barOpacity)
    }

    @ViewBuilder
    private var horizontalLayout: some View {
        HStack(spacing: 0) {
            ForEach(widgetConfig.order, id: \.self) { widgetID in
                widgetView(for: widgetID, isVertical: false)
            }
        }
    }

    @ViewBuilder
    private var verticalLayout: some View {
        VStack(spacing: 0) {
            ForEach(widgetConfig.order, id: \.self) { widgetID in
                widgetView(for: widgetID, isVertical: true)
            }
        }
    }

    @ViewBuilder
    private func widgetView(for id: String, isVertical: Bool) -> some View {
        let config = widgetConfig.parameters[id]

        switch id {
        case "workspaces":
            WorkspacesWidgetView(manager: manager, isVertical: isVertical, colors: colors, config: config)
        case "spacer":
            SpacerWidgetView()
        case "mode":
            ModeWidgetView(manager: manager, isVertical: isVertical, colors: colors, config: config)
        case "audio":
            AudioWidgetView(manager: manager, isVertical: isVertical, colors: colors, config: config)
        case "clock":
            ClockWidgetView(manager: manager, isVertical: isVertical, colors: colors, config: config)
        default:
            EmptyView()
        }
    }
}
