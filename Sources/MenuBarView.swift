import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var manager: MenuBarManager
    let barPosition: BarPosition
    let colors: ColorConfig
    let componentLayout: ComponentLayout
    let onWorkspaceClick: (String) -> Void
    let onQuit: () -> Void

    var body: some View {
        Group {
            switch barPosition {
            case .top, .bottom:
                dynamicHorizontalLayout
            case .left, .right:
                dynamicVerticalLayout
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

    // MARK: - Dynamic Layout Construction

    private var dynamicHorizontalLayout: some View {
        HStack(spacing: 0) {
            // Left components
            if !componentLayout.left.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(componentLayout.left.enumerated()), id: \.offset) { _, instance in
                        renderComponent(instance, isVertical: false)
                    }
                }
            }

            // Center components
            if !componentLayout.center.isEmpty {
                ForEach(Array(componentLayout.center.enumerated()), id: \.offset) { _, instance in
                    Spacer()
                    renderComponent(instance, isVertical: false)
                    Spacer()
                }
            } else if componentLayout.right.isEmpty {
                // No center and no right = spacer to push left to the edge
                Spacer()
            } else if !componentLayout.left.isEmpty {
                // Have left and right but no center = single spacer between them
                Spacer()
            }

            // Right components
            if !componentLayout.right.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(componentLayout.right.enumerated()), id: \.offset) { _, instance in
                        renderComponent(instance, isVertical: false)
                    }
                }
            }
        }
    }

    private var dynamicVerticalLayout: some View {
        VStack(spacing: 0) {
            // Left (top in vertical) components
            if !componentLayout.left.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(componentLayout.left.enumerated()), id: \.offset) { _, instance in
                        renderComponent(instance, isVertical: true)
                    }
                }
            }

            // Center components
            if !componentLayout.center.isEmpty {
                ForEach(Array(componentLayout.center.enumerated()), id: \.offset) { _, instance in
                    Spacer()
                    renderComponent(instance, isVertical: true)
                    Spacer()
                }
            } else if componentLayout.right.isEmpty {
                Spacer()
            } else if !componentLayout.left.isEmpty {
                Spacer()
            }

            // Right (bottom in vertical) components
            if !componentLayout.right.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(componentLayout.right.enumerated()), id: \.offset) { _, instance in
                        renderComponent(instance, isVertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderComponent(_ instance: ComponentInstance, isVertical: Bool) -> some View {
        let factory = ComponentFactory(
            manager: manager,
            colors: colors,
            onWorkspaceClick: onWorkspaceClick
        )

        let component = factory.makeComponent(for: instance)

        component.render(isVertical: isVertical)
            .padding(instance.padding.edgeInsets)
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
