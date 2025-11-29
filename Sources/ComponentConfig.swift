import Foundation
import SwiftUI

// MARK: - Component Configuration

/// Centering alignment for components
enum ComponentCentering: String, Codable {
    case left
    case center
    case right
}

/// Edge insets for component padding
struct ComponentPadding: Equatable {
    let top: CGFloat
    let right: CGFloat
    let bottom: CGFloat
    let left: CGFloat

    static let zero = ComponentPadding(top: 0, right: 0, bottom: 0, left: 0)

    /// Parse CSS-like padding syntax
    /// Supports: "10" (all), "10,20" (vertical,horizontal), "10,20,30,40" (top,right,bottom,left)
    init(from string: String) throws {
        let components = string.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        switch components.count {
        case 1:
            // "10" = all sides
            guard let value = Double(components[0]) else {
                throw ComponentConfigError.invalidPadding(string)
            }
            self.top = CGFloat(value)
            self.right = CGFloat(value)
            self.bottom = CGFloat(value)
            self.left = CGFloat(value)
        case 2:
            // "10,20" = vertical, horizontal
            guard let vertical = Double(components[0]),
                  let horizontal = Double(components[1]) else {
                throw ComponentConfigError.invalidPadding(string)
            }
            self.top = CGFloat(vertical)
            self.right = CGFloat(horizontal)
            self.bottom = CGFloat(vertical)
            self.left = CGFloat(horizontal)
        case 4:
            // "10,20,30,40" = top, right, bottom, left
            guard let top = Double(components[0]),
                  let right = Double(components[1]),
                  let bottom = Double(components[2]),
                  let left = Double(components[3]) else {
                throw ComponentConfigError.invalidPadding(string)
            }
            self.top = CGFloat(top)
            self.right = CGFloat(right)
            self.bottom = CGFloat(bottom)
            self.left = CGFloat(left)
        default:
            throw ComponentConfigError.invalidPadding(string)
        }
    }

    init(top: CGFloat, right: CGFloat, bottom: CGFloat, left: CGFloat) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    /// Convert to SwiftUI EdgeInsets
    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}

/// Type of component
enum ComponentType: String, Codable {
    case workspaces
    case clock

    static let allCases: [ComponentType] = [.workspaces, .clock]
    static let allCaseNames: [String] = allCases.map { $0.rawValue }
}

/// Configuration for a single component instance
struct ComponentInstance {
    let type: ComponentType
    let centering: ComponentCentering
    let padding: ComponentPadding
    let order: Int
}

/// Configuration error types
enum ComponentConfigError: Error, CustomStringConvertible {
    case missingComponentsSection
    case missingCentering(String)
    case invalidComponent(String)
    case invalidPadding(String)

    var description: String {
        switch self {
        case .missingComponentsSection:
            return "Error: Missing [components] section in configuration file"
        case .missingCentering(let component):
            return "Error: Component '\(component)' is missing required 'centering' property"
        case .invalidComponent(let name):
            return "Error: Invalid component: \(name). Allowed components are: \(ComponentType.allCaseNames.joined(separator: ", "))"
        case .invalidPadding(let value):
            return "Error: Invalid padding value '\(value)'. Expected format: '10' or '10,20' or '10,20,30,40'"
        }
    }
}

/// Layout buckets for organizing components by centering
struct ComponentLayout {
    let left: [ComponentInstance]
    let center: [ComponentInstance]
    let right: [ComponentInstance]

    init(components: [ComponentInstance]) {
        self.left = components.filter { $0.centering == .left }
        self.center = components.filter { $0.centering == .center }
        self.right = components.filter { $0.centering == .right }
    }
}
