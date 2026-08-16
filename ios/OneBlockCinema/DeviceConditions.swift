import Foundation
import UIKit

nonisolated enum DeviceThermalState: String, CaseIterable, Sendable {
    case nominal
    case fair
    case serious
    case critical

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .serious
        }
    }
}

nonisolated struct DeviceConditionSnapshot: Sendable, Equatable {
    let availableCapacity: Int64?
    let thermalState: DeviceThermalState

    var shouldDisableTorch: Bool {
        thermalState == .serious || thermalState == .critical
    }

    var blocksNewWork: Bool {
        thermalState == .critical
    }
}

nonisolated struct StorageBudgetPolicy: Sendable {
    static let mebibyte: Int64 = 1024 * 1024

    let captureStartBytes: Int64
    let captureStopBytes: Int64
    let minimumExportBytes: Int64
    let exportBytesPerSecond: Int64

    init(
        captureStartBytes: Int64 = 500 * mebibyte,
        captureStopBytes: Int64 = 250 * mebibyte,
        minimumExportBytes: Int64 = 100 * mebibyte,
        exportBytesPerSecond: Int64 = 4 * mebibyte
    ) {
        self.captureStartBytes = captureStartBytes
        self.captureStopBytes = captureStopBytes
        self.minimumExportBytes = minimumExportBytes
        self.exportBytesPerSecond = exportBytesPerSecond
    }

    func canStartCapture(availableBytes: Int64) -> Bool {
        availableBytes >= captureStartBytes
    }

    func shouldStopCapture(availableBytes: Int64) -> Bool {
        availableBytes < captureStopBytes
    }

    func requiredExportBytes(duration: TimeInterval) -> Int64 {
        max(minimumExportBytes, Int64(duration * Double(exportBytesPerSecond)))
    }
}

nonisolated protocol StorageCapacityProviding: Sendable {
    func availableCapacity(at url: URL) throws -> Int64?
}

nonisolated enum StorageCapacityPurpose: Sendable {
    case capture
    case export
}

nonisolated struct DeviceStorageCapacityProvider: StorageCapacityProviding {
    let purpose: StorageCapacityPurpose

    func availableCapacity(at url: URL) throws -> Int64? {
        #if DEBUG
            if let override = DeviceQAOverrideStore.shared.storageCapacityOverride(for: purpose) {
                return override
            }
        #endif
        return try SystemStorageCapacityProvider().availableCapacity(at: url)
    }
}

nonisolated struct SystemStorageCapacityProvider: StorageCapacityProviding {
    func availableCapacity(at url: URL) throws -> Int64? {
        try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }
}

nonisolated protocol ThermalStateProviding: Sendable {
    var thermalState: DeviceThermalState { get }
}

nonisolated struct SystemThermalStateProvider: ThermalStateProviding {
    var thermalState: DeviceThermalState {
        DeviceThermalState(ProcessInfo.processInfo.thermalState)
    }
}

nonisolated struct DeviceThermalStateProvider: ThermalStateProviding {
    var thermalState: DeviceThermalState {
        #if DEBUG
            if let override = DeviceQAOverrideStore.shared.thermalStateOverride {
                return override
            }
        #endif
        return SystemThermalStateProvider().thermalState
    }
}

nonisolated enum CameraInterruption: String, Sendable, Equatable {
    case audioDeviceInUse
    case videoDeviceInUse
    case multipleForegroundApps
    case systemPressure
    case deviceDisconnected
    case mediaServicesReset
    case appInactive
    case unknown

    var userFacingReason: String {
        switch self {
        case .audioDeviceInUse: "The microphone is being used by another app."
        case .videoDeviceInUse: "The camera is being used by another app."
        case .multipleForegroundApps: "Camera capture is unavailable while multiple apps are active."
        case .systemPressure: "The camera paused to protect this device."
        case .deviceDisconnected: "The selected camera disconnected."
        case .mediaServicesReset: "The camera service restarted."
        case .appInactive: "Camera capture paused while the app was inactive."
        case .unknown: "Camera capture was interrupted."
        }
    }
}

nonisolated struct BackgroundTaskToken: Hashable, Sendable {
    let id: UUID

    static let invalid = BackgroundTaskToken(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
}

@MainActor
protocol BackgroundTaskManaging: AnyObject {
    func begin(name: String, expiration: @escaping @MainActor () -> Void) -> BackgroundTaskToken
    func end(_ token: BackgroundTaskToken)
}

@MainActor
final class ApplicationBackgroundTaskManager: BackgroundTaskManaging {
    private var identifiers: [BackgroundTaskToken: UIBackgroundTaskIdentifier] = [:]

    func begin(name: String, expiration: @escaping @MainActor () -> Void) -> BackgroundTaskToken {
        let token = BackgroundTaskToken(id: UUID())
        let identifier = UIApplication.shared.beginBackgroundTask(withName: name) {
            Task { @MainActor in expiration() }
        }
        guard identifier != .invalid else { return .invalid }
        identifiers[token] = identifier
        return token
    }

    func end(_ token: BackgroundTaskToken) {
        guard token != .invalid, let identifier = identifiers.removeValue(forKey: token) else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }
}
