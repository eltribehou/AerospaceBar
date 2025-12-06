import SwiftUI

/// Flexible spacing widget (expands to fill available space)
struct SpacerWidget: MenuBarWidget {
    static let identifier = "spacer"
    static let displayName = "Spacer"
    static var defaultParameters: WidgetParameters { WidgetParameters() }

    init(parameters: WidgetParameters) {
        // No parameters to store
    }

    func render(manager: MenuBarManager, isVertical: Bool, colors: ColorConfig) -> AnyView {
        AnyView(Spacer())
    }
}
