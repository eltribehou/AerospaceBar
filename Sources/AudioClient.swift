import Foundation
import CoreAudio
import AppKit

/// Information about an audio output device
struct AudioDeviceInfo: Hashable {
    let name: String
    let icon: NSImage?
    let volume: Float  // Volume level from 0.0 to 1.0
}

/// Client for querying macOS audio output devices
class AudioClient {
    private var propertyListenerProc: AudioObjectPropertyListenerProc?
    fileprivate var currentDeviceID: AudioDeviceID?  // Track current device for listener management

    /// Start listening for audio device and volume changes
    /// Sends distributed notification "com.aerospacebar.refreshAudio" on changes
    func startListening() {
        // Create listener callback that sends refresh notification
        // The callback is called on a background thread, so we need to capture self weakly
        let listenerProc: AudioObjectPropertyListenerProc = { inObjectID, _, inAddresses, inClientData in
            DebugLogger.log("CoreAudio property changed - sending refresh notification")

            // Check if this is a device change notification
            let isDeviceChange = inAddresses.pointee.mSelector == kAudioHardwarePropertyDefaultOutputDevice

            if isDeviceChange {
                DebugLogger.log("Default audio device changed - re-registering volume listener")

                // Get the AudioClient instance from context (passed as inClientData)
                if let clientPtr = inClientData {
                    let client = Unmanaged<AudioClient>.fromOpaque(clientPtr).takeUnretainedValue()

                    // Remove old volume listener and add new one for the new device
                    if let oldDeviceID = client.currentDeviceID, let callback = client.propertyListenerProc {
                        client.removeVolumeListener(from: oldDeviceID, callback: callback)
                    }

                    if let newDeviceID = client.getDefaultOutputDeviceID(), let callback = client.propertyListenerProc {
                        client.currentDeviceID = newDeviceID
                        client.addVolumeListener(for: newDeviceID, callback: callback)
                    }
                }
            }

            DistributedNotificationCenter.default().post(
                name: NSNotification.Name("com.aerospacebar.refreshAudio"),
                object: nil
            )
            return noErr
        }

        self.propertyListenerProc = listenerProc

        // Listen for default output device changes
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Pass self as context so the callback can re-register volume listeners
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status1 = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            listenerProc,
            selfPtr
        )

        if status1 == noErr {
            DebugLogger.log("Started listening for audio device changes")
        } else {
            DebugLogger.log("Failed to add device change listener: \(status1)")
        }

        // Listen for volume changes on the current device
        if let deviceID = getDefaultOutputDeviceID() {
            currentDeviceID = deviceID
            addVolumeListener(for: deviceID, callback: listenerProc)
        }
    }

    /// Stop listening for audio changes
    func stopListening() {
        guard let listenerProc = propertyListenerProc else { return }

        // Remove default device listener
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            listenerProc,
            nil
        )

        // Remove volume listener from current device
        if let deviceID = getDefaultOutputDeviceID() {
            removeVolumeListener(from: deviceID, callback: listenerProc)
        }

        DebugLogger.log("Stopped listening for audio changes")
    }

    /// Add volume listener for a specific device
    private func addVolumeListener(for deviceID: AudioDeviceID, callback: AudioObjectPropertyListenerProc) {
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Only add listener if device has volume control
        guard AudioObjectHasProperty(deviceID, &volumeAddress) else {
            DebugLogger.log("Device \(deviceID) does not have volume property")
            return
        }

        let status = AudioObjectAddPropertyListener(
            deviceID,
            &volumeAddress,
            callback,
            nil
        )

        if status == noErr {
            DebugLogger.log("Started listening for volume changes on device \(deviceID)")
        } else {
            DebugLogger.log("Failed to add volume listener: \(status)")
        }
    }

    /// Remove volume listener from a specific device
    private func removeVolumeListener(from deviceID: AudioDeviceID, callback: AudioObjectPropertyListenerProc) {
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &volumeAddress) else { return }

        AudioObjectRemovePropertyListener(
            deviceID,
            &volumeAddress,
            callback,
            nil
        )
    }

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

        // Get the current volume level
        let volume = getDeviceVolume(deviceID: deviceID)

        return AudioDeviceInfo(name: deviceName, icon: icon, volume: volume)
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

    /// Get the volume level of an audio device
    /// Returns a value from 0.0 to 1.0, or 0.5 if unable to query
    private func getDeviceVolume(deviceID: AudioDeviceID) -> Float {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if the device has a volume property
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            DebugLogger.log("Device does not have volume property")
            return 0.5  // Default to 50% if no volume control
        }

        var volume: Float32 = 0.0
        var propertySize = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &volume
        )

        guard status == noErr else {
            DebugLogger.log("CoreAudio error getting device volume: \(status)")
            return 0.5  // Default to 50% on error
        }

        DebugLogger.log("Device volume: \(volume)")
        return volume
    }
}
