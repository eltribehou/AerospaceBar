import Foundation

/// Simple debug logging utility for AerospaceBar
/// Logs to stdout when debug mode is enabled via --debug flag
struct DebugLogger {
    // Global debug flag, set at app startup based on command line arguments
    static var isEnabled = false

    /// Log a debug message with timestamp if debug mode is enabled
    /// - Parameter message: The message to log
    static func log(_ message: String) {
        guard isEnabled else { return }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[DEBUG \(timestamp)] \(message)")
    }
}
