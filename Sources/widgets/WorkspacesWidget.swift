import SwiftUI
import AppKit
import TOMLKit

/// Workspaces widget displaying workspace buttons with app icons
struct WorkspacesWidgetView: View {
    @ObservedObject var manager: MenuBarManager
    let isVertical: Bool
    let colors: ColorConfig
    let maxIcons: Int
    let showCount: Bool
    let spacing: CGFloat
    let iconSize: CGFloat

    init(manager: MenuBarManager, isVertical: Bool, colors: ColorConfig, config: TOMLTable?) {
        self.manager = manager
        self.isVertical = isVertical
        self.colors = colors

        // Parse parameters with defaults
        self.maxIcons = config?["max-app-icons"]?.int ?? 3
        self.showCount = config?["show-app-count"]?.bool ?? true
        self.spacing = CGFloat(config?["workspace-spacing"]?.int ?? 4)
        self.iconSize = CGFloat(config?["icon-size"]?.int ?? 14)
    }

    var body: some View {
        if isVertical {
            VStack(spacing: spacing) {
                workspaceButtons
            }
            .padding(.top, 8)
        } else {
            HStack(spacing: spacing) {
                workspaceButtons
            }
            .padding(.leading, 8)
        }
    }

    @ViewBuilder
    private var workspaceButtons: some View {
        ForEach(manager.workspaces, id: \.self) { workspace in
            WorkspaceButton(
                workspace: workspace,
                isCurrent: workspace == manager.currentWorkspace,
                apps: manager.appsPerWorkspace[workspace] ?? [],
                isVertical: isVertical,
                colors: colors,
                maxIcons: maxIcons,
                showCount: showCount,
                iconSize: iconSize,
                onClick: {
                    manager.switchToWorkspace(workspace)
                }
            )
        }
    }
}

/// Individual workspace button view
struct WorkspaceButton: View {
    let workspace: String
    let isCurrent: Bool
    let apps: [AppInfo]
    let isVertical: Bool
    let colors: ColorConfig
    let maxIcons: Int
    let showCount: Bool
    let iconSize: CGFloat
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

                        // Show app icons
                        if !apps.isEmpty {
                            VStack(spacing: 2) {
                                ForEach(Array(apps.prefix(maxIcons)), id: \.self) { appInfo in
                                    AppIconView(
                                        appName: appInfo.name,
                                        isFullscreen: appInfo.isFullscreen,
                                        iconSize: iconSize,
                                        colors: colors
                                    )
                                }

                                // Show count if more apps than max
                                if showCount && apps.count > maxIcons {
                                    Text("+\(apps.count - maxIcons)")
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

                        // Show app icons
                        if !apps.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(Array(apps.prefix(maxIcons)), id: \.self) { appInfo in
                                    AppIconView(
                                        appName: appInfo.name,
                                        isFullscreen: appInfo.isFullscreen,
                                        iconSize: iconSize,
                                        colors: colors
                                    )
                                }

                                // Show count if more apps than max
                                if showCount && apps.count > maxIcons {
                                    Text("+\(apps.count - maxIcons)")
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

/// Individual app icon view with fullscreen badge
struct AppIconView: View {
    let appName: String
    let isFullscreen: Bool
    let iconSize: CGFloat
    let colors: ColorConfig

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // App icon
            if let nsImage = AppIconHelper.shared.getIcon(forAppName: appName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
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
