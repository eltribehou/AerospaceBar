import Foundation
import TOMLKit

let configPath = NSString(string: "~/.config/aerospacebar/aerospacebar.toml").expandingTildeInPath
let contents = try String(contentsOfFile: configPath)
let table = try TOMLTable(string: contents)

print("Testing widget parsing...")

if let widgetsArray = table["widgets"]?.array {
    print("Found widgets array with \(widgetsArray.count) entries")
    
    for (index, widgetValue) in widgetsArray.enumerated() {
        if let widgetTable = widgetValue.table {
            if let widgetType = widgetTable["type"]?.string {
                print("  Widget \(index): type=\(widgetType)")
            } else {
                print("  Widget \(index): MISSING TYPE")
            }
        }
    }
} else {
    print("ERROR: Could not find widgets array")
}
