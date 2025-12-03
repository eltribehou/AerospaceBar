import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var manager: MenuBarManager
    let barPosition: BarPosition
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
        .background(colors.background)
        .contextMenu {
            Button("Quit") {
                onQuit()
            }
        }
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

            // Mode (if active) + Clock on the right
            ModeView(isVertical: false, currentMode: manager.currentMode, colors: colors)
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

            // Mode (if active) + Clock on the bottom
            ModeView(isVertical: true, currentMode: manager.currentMode, colors: colors)
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
