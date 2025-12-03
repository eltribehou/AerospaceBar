import Foundation
import CoreAudio
import AppKit

/// Information about an audio output device
struct AudioDeviceInfo: Hashable {
    let name: String
    let icon: NSImage?
}

/// Client for querying macOS audio output devices
class AudioClient {

    /// Get the currently selected audio output device
    /// Returns nil if unable to query the device
    func getCurrentOutputDevice() -> AudioDeviceInfo? {
        DebugLogger.log("Querying current audio output device")

        // Get the default output device ID
        guard let deviceID = getDefaultOutputDeviceID() else {
            DebugLogger.log("Failed to get default output device ID")
            return nil
        }

        // Get the device name
        guard let deviceName = getDeviceName(deviceID: deviceID) else {
            DebugLogger.log("Failed to get device name for ID: \(deviceID)")
            return nil
        }

        DebugLogger.log("Current audio output device: \(deviceName)")

        // Try to get an icon for the device
        let icon = getDeviceIcon(deviceName: deviceName)

        return AudioDeviceInfo(name: deviceName, icon: icon)
    }

    /// Get the default audio output device ID
    private func getDefaultOutputDeviceID() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr else {
            DebugLogger.log("CoreAudio error getting default device: \(status)")
            return nil
        }

        return deviceID
    }

    /// Get the name of an audio device given its ID
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var deviceName: CFString = "" as CFString

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceName
        )

        guard status == noErr else {
            DebugLogger.log("CoreAudio error getting device name: \(status)")
            return nil
        }

        return deviceName as String
    }

    /// Get an icon for the audio device based on its name
    /// Uses SF Symbols for common device types
    private func getDeviceIcon(deviceName: String) -> NSImage? {
        let nameLower = deviceName.lowercased()

        // Map device names to SF Symbol names
        let symbolName: String? = {
            if nameLower.contains("airpods") {
                return "airpods"
            } else if nameLower.contains("built-in") || nameLower.contains("internal") {
                return "speaker.wave.2"
            } else if nameLower.contains("display") || nameLower.contains("hdmi") {
                return "display"
            } else if nameLower.contains("usb") {
                return "cable.connector"
            } else if nameLower.contains("bluetooth") || nameLower.contains("headphones") || nameLower.contains("headset") {
                return "headphones"
            } else {
                // Generic audio output icon
                return "hifispeaker"
            }
        }()

        guard let symbol = symbolName else {
            return nil
        }

        // Create SF Symbol image
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: symbol, accessibilityDescription: deviceName)?
            .withSymbolConfiguration(config)
    }
}
