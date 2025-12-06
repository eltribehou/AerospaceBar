import SwiftUI
import AppKit
import TOMLKit

/// Audio output widget showing device icon and volume bar
struct AudioWidgetView: View {
    @ObservedObject var manager: MenuBarManager
    let isVertical: Bool
    let colors: ColorConfig
    let showIcon: Bool
    let showVolumeBar: Bool
    let barWidth: CGFloat
    let barHeight: CGFloat

    init(manager: MenuBarManager, isVertical: Bool, colors: ColorConfig, config: TOMLTable?) {
        self.manager = manager
        self.isVertical = isVertical
        self.colors = colors
        self.showIcon = config?["show-icon"]?.bool ?? true
        self.showVolumeBar = config?["show-volume-bar"]?.bool ?? true
        self.barWidth = CGFloat(config?["volume-bar-width"]?.int ?? 3)
        self.barHeight = CGFloat(config?["volume-bar-height"]?.int ?? 16)
    }

    var body: some View {
        Group {
            if let device = manager.currentAudioDevice {
                HStack(spacing: 4) {
                    // Audio device icon
                    if showIcon {
                        if let icon = device.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                        } else {
                            Text(device.name)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(colors.textInactive)
                                .lineLimit(1)
                        }
                    }

                    // Volume bar (always vertical)
                    if showVolumeBar {
                        VStack(spacing: 0) {
                            GeometryReader { geometry in
                                let totalHeight = geometry.size.height
                                let filledHeight = totalHeight * CGFloat(device.volume)

                                VStack(spacing: 0) {
                                    Spacer()
                                        .frame(height: totalHeight - filledHeight)
                                    Rectangle()
                                        .fill(colors.textActive)
                                        .frame(height: filledHeight)
                                }
                            }
                        }
                        .frame(width: barWidth, height: barHeight)
                        .background(colors.textInactive.opacity(0.3))
                        .cornerRadius(barWidth / 2)
                    }
                }
                .padding(isVertical ? .bottom : .trailing, 4)
            }
        }
    }
}
