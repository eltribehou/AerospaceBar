import SwiftUI
import TOMLKit

/// Mode indicator widget showing current Aerospace keybind mode
struct ModeWidgetView: View {
    @ObservedObject var manager: MenuBarManager
    let isVertical: Bool
    let colors: ColorConfig
    let fontSize: CGFloat

    init(manager: MenuBarManager, isVertical: Bool, colors: ColorConfig, config: TOMLTable?) {
        self.manager = manager
        self.isVertical = isVertical
        self.colors = colors
        let sizeKey = isVertical ? "font-size-vertical" : "font-size-horizontal"
        let defaultSize = isVertical ? 8 : 11
        self.fontSize = CGFloat(config?[sizeKey]?.int ?? defaultSize)
    }

    var body: some View {
        Group {
            if let mode = manager.currentMode {
                Text(mode)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(colors.textInactive)
                    .padding(isVertical ? .bottom : .trailing, 4)
            }
        }
    }
}
