import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var manager: MenuBarManager
    let barPosition: BarPosition
    let barOpacity: Double
    let colors: ColorConfig
    let widgets: [MenuBarWidget]
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

    private var horizontalLayout: some View {
        HStack(spacing: 0) {
            ForEach(Array(widgets.enumerated()), id: \.offset) { index, widget in
                widget.render(manager: manager, isVertical: false, colors: colors)
            }
        }
    }

    private var verticalLayout: some View {
        VStack(spacing: 0) {
            ForEach(Array(widgets.enumerated()), id: \.offset) { index, widget in
                widget.render(manager: manager, isVertical: true, colors: colors)
            }
        }
    }
}
