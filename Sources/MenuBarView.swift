import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var manager: MenuBarManager
    let barPosition: BarPosition
    let barOpacity: Double
    let colors: ColorConfig
    let onWorkspaceClick: (String) -> Void
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
            // Workspaces on the left
            HStack(spacing: 4) {
                ForEach(manager.workspaces, id: \.self) { workspace in
                    WorkspaceButton(
                        workspace: workspace,
                        isCurrent: workspace == manager.currentWorkspace,
                        apps: manager.appsPerWorkspace[workspace] ?? [],
                        isVertical: false,
                        colors: colors,
                        onClick: {
                            onWorkspaceClick(workspace)
                        }
                    )
                }
            }
            .padding(.leading, 8)

            Spacer()

            // Mode (if active) + Audio + Clock on the right
            ModeView(isVertical: false, currentMode: manager.currentMode, colors: colors)
            AudioOutputView(isVertical: false, audioDevice: manager.currentAudioDevice, colors: colors)
            ClockView(isVertical: false, currentTime: manager.currentTime, colors: colors)
                .padding(.trailing, 8)
        }
    }

    private var verticalLayout: some View {
        VStack(spacing: 0) {
            // Workspaces on the top
            VStack(spacing: 4) {
                ForEach(manager.workspaces, id: \.self) { workspace in
                    WorkspaceButton(
                        workspace: workspace,
                        isCurrent: workspace == manager.currentWorkspace,
                        apps: manager.appsPerWorkspace[workspace] ?? [],
                        isVertical: true,
                        colors: colors,
                        onClick: {
                            onWorkspaceClick(workspace)
                        }
                    )
                }
            }
            .padding(.top, 8)

            Spacer()

            // Mode (if active) + Audio + Clock on the bottom
            ModeView(isVertical: true, currentMode: manager.currentMode, colors: colors)
            AudioOutputView(isVertical: true, audioDevice: manager.currentAudioDevice, colors: colors)
            ClockView(isVertical: true, currentTime: manager.currentTime, colors: colors)
                .padding(.bottom, 8)
        }
    }
}

struct WorkspaceButton: View {
    let workspace: String
    let isCurrent: Bool
    let apps: [AppInfo]
    let isVertical: Bool
    let colors: ColorConfig
    let onClick: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onClick) {
            Group {
                if isVertical {
                    VStack(spacing: 2) {
                        Text(workspace)
                            .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                            .foregroundColor(isCurrent ? colors.textActive : colors.textInactive)

                        // Show app icons (limit to first 3)
                        if !apps.isEmpty {
                            VStack(spacing: 2) {
                                ForEach(Array(apps.prefix(3)), id: \.self) { appInfo in
                                    AppIconView(appName: appInfo.name, isFullscreen: appInfo.isFullscreen, colors: colors)
                                }

                                // Show count if more than 3 apps
                                if apps.count > 3 {
                                    Text("+\(apps.count - 3)")
                                        .font(.system(size: 8))
                                        .foregroundColor(colors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 8)
                } else {
                    HStack(spacing: 4) {
                        Text(workspace)
                            .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                            .foregroundColor(isCurrent ? colors.textActive : colors.textInactive)

                        // Show app icons (limit to first 3)
                        if !apps.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(Array(apps.prefix(3)), id: \.self) { appInfo in
                                    AppIconView(appName: appInfo.name, isFullscreen: appInfo.isFullscreen, colors: colors)
                                }

                                // Show count if more than 3 apps
                                if apps.count > 3 {
                                    Text("+\(apps.count - 3)")
                                        .font(.system(size: 8))
                                        .foregroundColor(colors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private var backgroundColor: Color {
        if isCurrent {
            return colors.workspaceActiveBackground
        } else if isHovering {
            return colors.workspaceHoverBackground
        } else {
            return colors.workspaceDefaultBackground
        }
    }
}

struct AppIconView: View {
    let appName: String
    let isFullscreen: Bool
    let colors: ColorConfig

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // App icon
            if let nsImage = AppIconHelper.shared.getIcon(forAppName: appName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .cornerRadius(2)
            }

            // Fullscreen badge overlay
            if isFullscreen {
                ZStack {
                    Circle()
                        .fill(colors.fullscreenBadgeBackground)
                        .frame(width: 6, height: 6)

                    Text("⛶")
                        .font(.system(size: 4))
                        .foregroundColor(colors.fullscreenBadgeSymbol)
                }
                .offset(x: 2, y: -2)
            }
        }
    }
}

struct ClockView: View {
    let isVertical: Bool
    let currentTime: Date
    let colors: ColorConfig

    var body: some View {
        Text(timeString)
            .font(.system(size: isVertical ? 8 : 12, weight: .regular))
            .foregroundColor(colors.textClock)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
}

struct ModeView: View {
    let isVertical: Bool
    let currentMode: String?
    let colors: ColorConfig

    var body: some View {
        // Only render if mode-command is configured (currentMode is non-nil)
        if let mode = currentMode {
            Text(mode)
                .font(.system(size: isVertical ? 8 : 11, weight: .medium))
                .foregroundColor(colors.textInactive)
                .padding(isVertical ? .bottom : .trailing, 4)  // Small spacing before clock
        }
    }
}

struct AudioOutputView: View {
    let isVertical: Bool
    let audioDevice: AudioDeviceInfo?
    let colors: ColorConfig

    var body: some View {
        // Only render if audio device info is available
        if let device = audioDevice {
            Group {
                if isVertical {
                    VStack(spacing: 2) {
                        if let icon = device.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                        }
                        VolumeIndicatorView(isVertical: true, volume: device.volume, colors: colors)
                    }
                } else {
                    HStack(spacing: 4) {
                        if let icon = device.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                        } else {
                            // Fall back to device name text
                            Text(device.name)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(colors.textInactive)
                                .lineLimit(1)
                        }
                        VolumeIndicatorView(isVertical: false, volume: device.volume, colors: colors)
                    }
                }
            }
            .padding(isVertical ? .bottom : .trailing, 4)  // Small spacing before clock
        }
    }
}

struct VolumeIndicatorView: View {
    let isVertical: Bool
    let volume: Float  // 0.0 to 1.0
    let colors: ColorConfig

    var body: some View {
        if isVertical {
            // Vertical bar for vertical layout
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let totalHeight = geometry.size.height
                    let filledHeight = totalHeight * CGFloat(volume)

                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: totalHeight - filledHeight)
                        Rectangle()
                            .fill(colors.textActive)
                            .frame(height: filledHeight)
                    }
                }
            }
            .frame(width: 3, height: 20)
            .background(colors.textInactive.opacity(0.3))
            .cornerRadius(1.5)
        } else {
            // Horizontal bar for horizontal layout
            HStack(spacing: 0) {
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let filledWidth = totalWidth * CGFloat(volume)

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(colors.textActive)
                            .frame(width: filledWidth)
                        Spacer()
                            .frame(width: totalWidth - filledWidth)
                    }
                }
            }
            .frame(width: 30, height: 3)
            .background(colors.textInactive.opacity(0.3))
            .cornerRadius(1.5)
        }
    }
}
