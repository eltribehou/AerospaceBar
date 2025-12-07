import SwiftUI
import AppKit
import TOMLKit

/// Workspaces widget displaying workspace buttons with app icons
struct WorkspacesWidgetView: View {
    @ObservedObject var manager: MenuBarManager
    let isVertical: Bool
    let barSize: CGFloat
    let showWindowCount: Bool
    let colors: ColorConfig
    let showCount: Bool
    let spacing: CGFloat
    let iconSize: CGFloat
    let borderMargin: CGFloat
    let maxWorkspaceSize: CGFloat?

    init(manager: MenuBarManager, isVertical: Bool, barSize: CGFloat, showWindowCount: Bool, colors: ColorConfig, config: TOMLTable?) {
        self.manager = manager
        self.isVertical = isVertical
        self.barSize = barSize
        self.showWindowCount = showWindowCount
        self.colors = colors

        // Parse parameters with defaults
        self.showCount = config?["show-app-count"]?.bool ?? true
        self.spacing = CGFloat(config?["workspace-spacing"]?.int ?? 4)
        self.iconSize = CGFloat(config?["icon-size"]?.int ?? 14)
        self.borderMargin = CGFloat(config?["border-margin"]?.int ?? 8)
        self.maxWorkspaceSize = config?["max-workspace-size"]?.int.map { CGFloat($0) }
    }

    var body: some View {
        Group {
            if isVertical {
                VStack(spacing: spacing) {
                    workspaceButtons
                }
                .padding(.top, 8)
                .padding(.horizontal, borderMargin)
            } else {
                HStack(spacing: spacing) {
                    workspaceButtons
                }
                .padding(.leading, 8)
                .padding(.vertical, borderMargin)
            }
        }
        .frame(maxWidth: isVertical ? .infinity : nil, maxHeight: isVertical ? nil : .infinity)
    }

    @ViewBuilder
    private var workspaceButtons: some View {
        ForEach(manager.workspaces, id: \.self) { workspace in
            WorkspaceButton(
                workspace: workspace,
                isCurrent: workspace == manager.currentWorkspace,
                apps: manager.appsPerWorkspace[workspace] ?? [],
                isVertical: isVertical,
                barSize: barSize,
                showWindowCount: showWindowCount,
                colors: colors,
                showCount: showCount,
                iconSize: iconSize,
                maxWorkspaceSize: maxWorkspaceSize,
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
    let barSize: CGFloat
    let showWindowCount: Bool
    let colors: ColorConfig
    let showCount: Bool
    let iconSize: CGFloat
    let maxWorkspaceSize: CGFloat?
    let onClick: () -> Void

    @State private var isHovering = false

    // Calculate icons per row based on bar size
    private var iconsPerRow: Int {
        if isVertical {
            // For vertical bars, bar size is the width
            let horizontalPadding: CGFloat = 4  // 2px on each side
            let iconSpacing: CGFloat = 2
            let availableWidth = barSize - horizontalPadding
            let iconsWithSpacing = (availableWidth + iconSpacing) / (iconSize + iconSpacing)
            return max(1, Int(iconsWithSpacing))
        } else {
            // For horizontal bars, icons are in a single row
            return 1
        }
    }

    var body: some View {
        Button(action: onClick) {
            Group {
                if isVertical {
                    verticalLayout
                } else {
                    horizontalLayout
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

    @ViewBuilder
    private var verticalLayout: some View {
        let (visibleIcons, rows) = calculateVisibleIconsVertical()

        VStack(alignment: .center, spacing: 2) {
            Text(workspace)
                .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                .foregroundColor(isCurrent ? colors.textActive : colors.textInactive)

            // Show app icons in grid layout
            if !apps.isEmpty {
                VStack(alignment: .center, spacing: 2) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(0..<iconsPerRow, id: \.self) { col in
                                let index = row * iconsPerRow + col
                                if index < visibleIcons {
                                    AppIconView(
                                        appName: apps[index].name,
                                        isFullscreen: apps[index].isFullscreen,
                                        windowCount: apps[index].windowCount,
                                        showWindowCount: showWindowCount,
                                        iconSize: iconSize,
                                        colors: colors
                                    )
                                }
                            }
                        }
                    }

                    // Show count if more apps than visible
                    if showCount && apps.count > visibleIcons {
                        Text("+\(apps.count - visibleIcons)")
                            .font(.system(size: 8))
                            .foregroundColor(colors.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(workspace)
                .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                .foregroundColor(isCurrent ? colors.textActive : colors.textInactive)
                .fixedSize()

            // Show app icons
            if !apps.isEmpty {
                HStack(spacing: 2) {
                    let visibleIcons = calculateVisibleIconsHorizontal()
                    ForEach(Array(apps.prefix(visibleIcons)), id: \.self) { appInfo in
                        AppIconView(
                            appName: appInfo.name,
                            isFullscreen: appInfo.isFullscreen,
                            windowCount: appInfo.windowCount,
                            showWindowCount: showWindowCount,
                            iconSize: iconSize,
                            colors: colors
                        )
                    }

                    // Show count if more apps than visible
                    if showCount && apps.count > visibleIcons {
                        Text("+\(apps.count - visibleIcons)")
                            .font(.system(size: 8))
                            .foregroundColor(colors.textSecondary)
                            .fixedSize()
                    }
                }
            }
        }
        .fixedSize()
        .frame(maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
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

    /// Calculate visible icons and rows for vertical layout (grid)
    /// Returns (visibleIcons, numberOfRows)
    private func calculateVisibleIconsVertical() -> (Int, Int) {
        if apps.isEmpty {
            return (0, 0)
        }

        // Constants
        let labelHeight: CGFloat = 16
        let iconSpacing: CGFloat = 2
        let countLabelHeight: CGFloat = 12
        let padding: CGFloat = 16

        // Calculate how many rows we can fit
        let maxRows: Int
        if let maxSize = maxWorkspaceSize {
            // Reserve space for count label (we'll check later if needed)
            let availableHeight = maxSize - padding - labelHeight - countLabelHeight
            let rowHeight = iconSize + iconSpacing
            maxRows = max(1, Int(availableHeight / rowHeight))
        } else {
            // No limit, show all apps
            maxRows = Int.max
        }

        // Calculate how many icons we can show
        let maxIconsToShow = maxRows * iconsPerRow
        let visibleIcons = min(maxIconsToShow, apps.count)
        let actualRows = (visibleIcons + iconsPerRow - 1) / iconsPerRow

        // If we're showing all apps, we don't need the count label
        // So recalculate if we have extra space
        if visibleIcons == apps.count, let maxSize = maxWorkspaceSize {
            // We don't need count label - recalculate with that space
            let availableHeight = maxSize - padding - labelHeight
            let rowHeight = iconSize + iconSpacing
            let recalcMaxRows = max(1, Int(availableHeight / rowHeight))

            if recalcMaxRows > actualRows {
                // We have more space now
                let recalcMaxIcons = recalcMaxRows * iconsPerRow
                let recalcVisible = min(recalcMaxIcons, apps.count)
                let recalcRows = (recalcVisible + iconsPerRow - 1) / iconsPerRow
                return (recalcVisible, recalcRows)
            }
        }

        return (visibleIcons, actualRows)
    }

    /// Calculate visible icons for horizontal layout
    private func calculateVisibleIconsHorizontal() -> Int {
        if apps.isEmpty {
            return 0
        }

        guard let maxSize = maxWorkspaceSize else {
            // No limit, show all apps
            return apps.count
        }

        let labelWidth: CGFloat = CGFloat(workspace.count) * 7 + 4
        let padding: CGFloat = 16
        let countLabelWidth: CGFloat = 20
        var availableWidth = maxSize - padding - labelWidth

        // Try to fit all apps first (without count label)
        let iconSpacing: CGFloat = 2
        var iconsCount = 0
        var usedWidth: CGFloat = 0

        for i in 0..<apps.count {
            let spaceNeeded = iconSize + (i > 0 ? iconSpacing : 0)
            if usedWidth + spaceNeeded <= availableWidth {
                usedWidth += spaceNeeded
                iconsCount += 1
            } else {
                break
            }
        }

        // If we can't fit all, reserve space for count label and recalculate
        if iconsCount < apps.count && showCount {
            availableWidth -= countLabelWidth
            iconsCount = 0
            usedWidth = 0

            for i in 0..<apps.count {
                let spaceNeeded = iconSize + (i > 0 ? iconSpacing : 0)
                if usedWidth + spaceNeeded <= availableWidth {
                    usedWidth += spaceNeeded
                    iconsCount += 1
                } else {
                    break
                }
            }
        }

        return max(0, iconsCount)
    }
}

/// Individual app icon view with fullscreen badge and window count
struct AppIconView: View {
    let appName: String
    let isFullscreen: Bool
    let windowCount: Int
    let showWindowCount: Bool
    let iconSize: CGFloat
    let colors: ColorConfig

    @State private var icon: NSImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // App icon - show if loaded, otherwise placeholder
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .cornerRadius(2)
            } else {
                // Placeholder while loading
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: iconSize, height: iconSize)
            }

            // Fullscreen badge overlay (top-right)
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
        .overlay(alignment: .bottomLeading) {
            // Window count badge (bottom-left, only if enabled and > 1 window)
            if showWindowCount && windowCount > 1 {
                Text("\(windowCount)")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.75))
                    )
                    .offset(x: -3, y: 3)
            }
        }
        .onAppear {
            AppIconHelper.shared.getIcon(forAppName: appName) { loadedIcon in
                self.icon = loadedIcon
            }
        }
    }
}
