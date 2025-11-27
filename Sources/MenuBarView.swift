import SwiftUI
import AppKit

struct MenuBarView: View {
    let workspaces: [String]
    let currentWorkspace: String?
    let appsPerWorkspace: [String: [AppInfo]]
    let onWorkspaceClick: (String) -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Workspaces on the left
            HStack(spacing: 4) {
                ForEach(workspaces, id: \.self) { workspace in
                    WorkspaceButton(
                        workspace: workspace,
                        isCurrent: workspace == currentWorkspace,
                        apps: appsPerWorkspace[workspace] ?? [],
                        onClick: {
                            onWorkspaceClick(workspace)
                        }
                    )
                }
            }
            .padding(.leading, 8)

            Spacer()

            // Quit button on the right
            Button(action: onQuit) {
                Text("Quit")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 8)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.1, opacity: 0.95))
    }
}

struct WorkspaceButton: View {
    let workspace: String
    let isCurrent: Bool
    let apps: [AppInfo]
    let onClick: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 4) {
                Text(workspace)
                    .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                    .foregroundColor(isCurrent ? .white : .white.opacity(0.7))

                // Show app icons (limit to first 3)
                if !apps.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(apps.prefix(3)), id: \.self) { appInfo in
                            AppIconView(appName: appInfo.name, isFullscreen: appInfo.isFullscreen)
                        }

                        // Show count if more than 3 apps
                        if apps.count > 3 {
                            Text("+\(apps.count - 3)")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
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
            return Color.blue.opacity(0.6)
        } else if isHovering {
            return Color.white.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

struct AppIconView: View {
    let appName: String
    let isFullscreen: Bool

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
                        .fill(Color.green)
                        .frame(width: 6, height: 6)

                    Text("⛶")
                        .font(.system(size: 4))
                        .foregroundColor(.white)
                }
                .offset(x: 2, y: -2)
            }
        }
    }
}
