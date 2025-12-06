import SwiftUI
import TOMLKit

/// Flexible spacing widget (expands to fill available space)
/// Can also be configured for fixed pixel or percentage-based spacing
struct SpacerWidgetView: View {
    let isVertical: Bool
    let spacingMode: SpacingMode

    enum SpacingMode {
        case flexible                    // Default: expands to fill
        case fixed(CGFloat)              // Fixed pixels
        case percentage(Double)          // Percentage of screen dimension
    }

    init(isVertical: Bool, config: TOMLTable?) {
        self.isVertical = isVertical

        // Parse size parameter if present
        if let sizeString = config?["size"]?.string {
            if sizeString.hasSuffix("%") {
                // Percentage mode: "10%" -> 0.10
                let percentStr = String(sizeString.dropLast())
                if let percent = Double(percentStr) {
                    self.spacingMode = .percentage(percent / 100.0)
                } else {
                    print("Warning: Invalid percentage value '\(sizeString)', using flexible spacer")
                    self.spacingMode = .flexible
                }
            } else {
                // Fixed pixel mode: "16" -> 16.0
                if let pixels = Double(sizeString) {
                    self.spacingMode = .fixed(CGFloat(pixels))
                } else {
                    print("Warning: Invalid size value '\(sizeString)', using flexible spacer")
                    self.spacingMode = .flexible
                }
            }
        } else {
            // No size parameter -> flexible mode (backward compatible)
            self.spacingMode = .flexible
        }
    }

    var body: some View {
        switch spacingMode {
        case .flexible:
            Spacer()

        case .fixed(let pixels):
            Spacer()
                .frame(
                    width: isVertical ? nil : pixels,
                    height: isVertical ? pixels : nil
                )

        case .percentage(let percent):
            GeometryReader { geometry in
                let screenDimension = isVertical ? geometry.size.height : geometry.size.width
                let calculatedSize = screenDimension * CGFloat(percent)

                Spacer()
                    .frame(
                        width: isVertical ? nil : calculatedSize,
                        height: isVertical ? calculatedSize : nil
                    )
            }
            .frame(
                width: isVertical ? nil : 0,
                height: isVertical ? 0 : nil
            )
        }
    }
}
