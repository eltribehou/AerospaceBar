import SwiftUI

struct MenuBarView: View {
    let workspaces: [String]
    let currentWorkspace: String?
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
    let onClick: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onClick) {
            Text(workspace)
                .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                .foregroundColor(isCurrent ? .white : .white.opacity(0.7))
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
