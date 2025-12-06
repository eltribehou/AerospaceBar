import SwiftUI
import AppKit

/// Audio output widget showing device icon and volume bar
struct AudioWidget: ParameterizedWidget {
    static let identifier = "audio"
    static let displayName = "Audio Output"

    static let parameterDefinitions: [WidgetParameterDefinition] = [
        WidgetParameterDefinition(
            key: "show-icon",
            type: .bool,
            defaultValue: true,
            description: "Show audio device icon"
        ),
        WidgetParameterDefinition(
            key: "show-volume-bar",
            type: .bool,
            defaultValue: true,
            description: "Show volume level bar"
        ),
        WidgetParameterDefinition(
            key: "volume-bar-width",
            type: .int,
            defaultValue: 3,
            description: "Width of volume bar in pixels"
        ),
        WidgetParameterDefinition(
            key: "volume-bar-height",
            type: .int,
            defaultValue: 16,
            description: "Height of volume bar in pixels"
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
        let showIcon = parameters.getBool("show-icon", default: true)
        let showVolumeBar = parameters.getBool("show-volume-bar", default: true)
        let barWidth = CGFloat(parameters.getInt("volume-bar-width", default: 3))
        let barHeight = CGFloat(parameters.getInt("volume-bar-height", default: 16))

        let content = Group {
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

        return AnyView(content)
    }
}
