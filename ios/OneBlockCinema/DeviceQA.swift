#if DEBUG
    import AVFoundation
    import Foundation
    import SwiftUI
    import UIKit

    nonisolated extension Notification.Name {
        static let deviceQACameraInterruptionBegan = Notification.Name("OBC.deviceQA.cameraInterruptionBegan")
        static let deviceQACameraInterruptionEnded = Notification.Name("OBC.deviceQA.cameraInterruptionEnded")
        static let deviceQAMediaServicesReset = Notification.Name("OBC.deviceQA.mediaServicesReset")
        static let deviceQAExportBackgroundExpiration = Notification.Name("OBC.deviceQA.exportBackgroundExpiration")
    }

    final nonisolated class DeviceQAOverrideStore: @unchecked Sendable {
        static let shared = DeviceQAOverrideStore()

        private struct State {
            var lowCaptureStorage = false
            var lowExportStorage = false
            var thermalState: DeviceThermalState?
            var latestCameraInterruption: String?
            var latestExportInterruption: String?
        }

        private let lock = NSLock()
        private var state = State()

        var thermalStateOverride: DeviceThermalState? {
            lock.withLock { state.thermalState }
        }

        func storageCapacityOverride(for purpose: StorageCapacityPurpose) -> Int64? {
            lock.withLock {
                switch purpose {
                case .capture where state.lowCaptureStorage: 249 * StorageBudgetPolicy.mebibyte
                case .export where state.lowExportStorage: 99 * StorageBudgetPolicy.mebibyte
                default: nil
                }
            }
        }

        func setLowStorage(_ enabled: Bool, for purpose: StorageCapacityPurpose) {
            lock.withLock {
                switch purpose {
                case .capture: state.lowCaptureStorage = enabled
                case .export: state.lowExportStorage = enabled
                }
            }
        }

        func setThermalState(_ thermalState: DeviceThermalState?) {
            lock.withLock { state.thermalState = thermalState }
            NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        }

        func recordCameraInterruption(_ reason: String) {
            lock.withLock { state.latestCameraInterruption = reason }
        }

        func recordExportInterruption(_ reason: String) {
            lock.withLock { state.latestExportInterruption = reason }
        }

        func latestInterruptions() -> (camera: String, export: String) {
            lock.withLock {
                (state.latestCameraInterruption ?? "None", state.latestExportInterruption ?? "None")
            }
        }
    }

    struct DeviceQAPanel: View {
        @State private var lowCaptureStorage = false
        @State private var lowExportStorage = false
        @State private var thermalOverride: DeviceThermalState?
        @State private var refreshID = UUID()

        var body: some View {
            Section("Device QA") {
                diagnostics

                Toggle("Inject low capture storage", isOn: $lowCaptureStorage)
                    .onChange(of: lowCaptureStorage) { _, enabled in
                        DeviceQAOverrideStore.shared.setLowStorage(enabled, for: .capture)
                    }
                Toggle("Inject low export storage", isOn: $lowExportStorage)
                    .onChange(of: lowExportStorage) { _, enabled in
                        DeviceQAOverrideStore.shared.setLowStorage(enabled, for: .export)
                    }

                Picker("Thermal override", selection: $thermalOverride) {
                    Text("Actual").tag(DeviceThermalState?.none)
                    Text("Serious").tag(DeviceThermalState?.some(.serious))
                    Text("Critical").tag(DeviceThermalState?.some(.critical))
                }
                .onChange(of: thermalOverride) { _, value in
                    DeviceQAOverrideStore.shared.setThermalState(value)
                    refreshID = UUID()
                }

                Button("Begin camera interruption") {
                    NotificationCenter.default.post(name: .deviceQACameraInterruptionBegan, object: nil)
                    refreshID = UUID()
                }
                Button("End camera interruption") {
                    NotificationCenter.default.post(name: .deviceQACameraInterruptionEnded, object: nil)
                    refreshID = UUID()
                }
                Button("Simulate media-services reset") {
                    NotificationCenter.default.post(name: .deviceQAMediaServicesReset, object: nil)
                    refreshID = UUID()
                }
                Button("Expire export background time") {
                    NotificationCenter.default.post(name: .deviceQAExportBackgroundExpiration, object: nil)
                    refreshID = UUID()
                }

                Text("Faults change injected app services only. They do not alter device storage or temperature.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .id(refreshID)
        }

        private var diagnostics: some View {
            let interruptions = DeviceQAOverrideStore.shared.latestInterruptions()
            let freeCapacity = try? SystemStorageCapacityProvider().availableCapacity(
                at: FileManager.default.temporaryDirectory
            )
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            return Group {
                LabeledContent("Device", value: Self.hardwareModel)
                LabeledContent("OS", value: UIDevice.current.systemVersion)
                LabeledContent("Free capacity", value: freeCapacity.flatMap(Self.formattedCapacity) ?? "Unknown")
                LabeledContent("Thermal state", value: DeviceThermalStateProvider().thermalState.rawValue.capitalized)
                LabeledContent("Camera", value: camera.map(Self.cameraDescription) ?? "Unavailable")
                LabeledContent("Latest camera interruption", value: interruptions.camera)
                LabeledContent("Latest export interruption", value: interruptions.export)
            }
        }

        private nonisolated static var hardwareModel: String {
            var systemInfo = utsname()
            uname(&systemInfo)
            return withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
            }
        }

        private nonisolated static func formattedCapacity(_ bytes: Int64) -> String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        private nonisolated static func cameraDescription(_ camera: AVCaptureDevice) -> String {
            let torch = camera.hasTorch ? "torch" : "no torch"
            let zoom = String(format: "%.1fx", min(camera.activeFormat.videoMaxZoomFactor, 6))
            return "Back, \(torch), \(zoom)"
        }
    }
#endif
