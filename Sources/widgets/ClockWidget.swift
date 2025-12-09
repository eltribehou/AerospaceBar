import SwiftUI
import TOMLKit

/// Clock widget displaying current time
struct ClockWidgetView: View {
    let isVertical: Bool
    let colors: ColorConfig
    let format: String
    let fontSize: CGFloat

    @State private var currentTime = Date()

    // Timer publisher that fires every second
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(manager: MenuBarManager, isVertical: Bool, colors: ColorConfig, config: TOMLTable?) {
        self.isVertical = isVertical
        self.colors = colors
        self.format = config?["format"]?.string ?? "HH:mm"
        let sizeKey = isVertical ? "font-size-vertical" : "font-size-horizontal"
        let defaultSize = isVertical ? 8 : 12
        self.fontSize = CGFloat(config?[sizeKey]?.int ?? defaultSize)
    }

    var body: some View {
        Text(timeString)
            .font(.system(size: fontSize, weight: .regular))
            .foregroundColor(colors.textClock)
            .padding(isVertical ? .bottom : .trailing, 8)
            .onReceive(timer) { newTime in
                currentTime = newTime
            }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: currentTime)
    }
}
