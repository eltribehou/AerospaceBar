import SwiftUI

/// Protocol that all menubar components must conform to
protocol MenuBarComponent {
    /// Render the component for a given orientation
    func render(isVertical: Bool) -> AnyView

    /// The component's type
    var componentType: ComponentType { get }
}

/// Factory for creating component instances
struct ComponentFactory {
    let manager: MenuBarManager
    let colors: ColorConfig
    let onWorkspaceClick: (String) -> Void

    /// Create a component instance from configuration
    func makeComponent(for instance: ComponentInstance) -> any MenuBarComponent {
        switch instance.type {
        case .workspaces:
            return WorkspacesComponent(
                manager: manager,
                colors: colors,
                onWorkspaceClick: onWorkspaceClick
            )
        case .clock:
            return ClockComponent(
                manager: manager,
                colors: colors
            )
        }
    }
}

// MARK: - Concrete Component Implementations

struct WorkspacesComponent: MenuBarComponent {
    let manager: MenuBarManager
    let colors: ColorConfig
    let onWorkspaceClick: (String) -> Void

    var componentType: ComponentType { .workspaces }

    func render(isVertical: Bool) -> AnyView {
        if isVertical {
            return AnyView(
                VStack(spacing: 4) {
                    ForEach(manager.workspaces, id: \.self) { workspace in
                        WorkspaceButton(
                            workspace: workspace,
                            isCurrent: workspace == manager.currentWorkspace,
                            apps: manager.appsPerWorkspace[workspace] ?? [],
                            isVertical: true,
                            colors: colors,
                            onClick: { onWorkspaceClick(workspace) }
                        )
                    }
                }
            )
        } else {
            return AnyView(
                HStack(spacing: 4) {
                    ForEach(manager.workspaces, id: \.self) { workspace in
                        WorkspaceButton(
                            workspace: workspace,
                            isCurrent: workspace == manager.currentWorkspace,
                            apps: manager.appsPerWorkspace[workspace] ?? [],
                            isVertical: false,
                            colors: colors,
                            onClick: { onWorkspaceClick(workspace) }
                        )
                    }
                }
            )
        }
    }
}

struct ClockComponent: MenuBarComponent {
    let manager: MenuBarManager
    let colors: ColorConfig

    var componentType: ComponentType { .clock }

    func render(isVertical: Bool) -> AnyView {
        return AnyView(
            ClockView(
                isVertical: isVertical,
                currentTime: manager.currentTime,
                colors: colors
            )
        )
    }
}
