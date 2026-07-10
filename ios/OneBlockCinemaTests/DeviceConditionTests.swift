import Foundation
@testable import OneBlockCinema
import Testing

struct DeviceConditionTests {
    @Test func storageBudgetUsesCaptureThresholdsAndConservativeExportEstimate() {
        let policy = StorageBudgetPolicy()

        #expect(policy.canStartCapture(availableBytes: 500 * 1024 * 1024))
        #expect(!policy.canStartCapture(availableBytes: 500 * 1024 * 1024 - 1))
        #expect(policy.shouldStopCapture(availableBytes: 250 * 1024 * 1024 - 1))
        #expect(!policy.shouldStopCapture(availableBytes: 250 * 1024 * 1024))
        #expect(policy.requiredExportBytes(duration: 5) == 100 * 1024 * 1024)
        #expect(policy.requiredExportBytes(duration: 180) == 720 * 1024 * 1024)
    }

    @Test func deviceSnapshotAppliesThermalPolicy() {
        let serious = DeviceConditionSnapshot(availableCapacity: 1000, thermalState: .serious)
        let critical = DeviceConditionSnapshot(availableCapacity: 1000, thermalState: .critical)

        #expect(serious.shouldDisableTorch)
        #expect(!serious.blocksNewWork)
        #expect(critical.shouldDisableTorch)
        #expect(critical.blocksNewWork)
    }

    @Test func fixedProvidersMakeDeviceConditionsDeterministic() throws {
        let storage = FixedStorageCapacityProvider(availableCapacity: 42)
        let thermal = FixedThermalStateProvider(thermalState: .critical)

        #expect(try storage.availableCapacity(at: FileManager.default.temporaryDirectory) == 42)
        #expect(thermal.thermalState == .critical)
    }

    @Test func exportPreflightRejectsLowStorage() async {
        let service = VideoExportService(
            storageCapacityProvider: FixedStorageCapacityProvider(availableCapacity: 99 * 1024 * 1024),
            thermalStateProvider: FixedThermalStateProvider(thermalState: .nominal)
        )

        do {
            _ = try await service.render(plan: VideoExportLimits.plan(for: []))
            Issue.record("Expected low-storage preflight to fail")
        } catch let ExportError.insufficientStorage(required, available) {
            #expect(required == 100)
            #expect(available == 99)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func exportPreflightRejectsCriticalThermalState() async {
        let service = VideoExportService(
            storageCapacityProvider: FixedStorageCapacityProvider(availableCapacity: 1000 * 1024 * 1024),
            thermalStateProvider: FixedThermalStateProvider(thermalState: .critical)
        )

        do {
            _ = try await service.render(plan: VideoExportLimits.plan(for: []))
            Issue.record("Expected critical thermal preflight to fail")
        } catch ExportError.criticalThermalState {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func cameraRecoveryStateMachinePreservesInterruptionReason() {
        let interrupted = CameraRecoveryStateMachine.transition(
            from: .ready,
            event: .interruptionBegan(.videoDeviceInUse)
        )
        #expect(interrupted == .interrupted(.videoDeviceInUse))

        let recovering = CameraRecoveryStateMachine.transition(from: interrupted, event: .interruptionEnded)
        #expect(recovering == .recovering(.videoDeviceInUse))
        #expect(CameraRecoveryStateMachine.transition(from: recovering, event: .recoverySucceeded) == .ready)
    }

    @Test func cameraRecoveryStateMachineHandlesMediaServiceResetAndFailure() {
        let recovering = CameraRecoveryStateMachine.transition(from: .ready, event: .mediaServicesReset)
        #expect(recovering == .recovering(.mediaServicesReset))
        #expect(
            CameraRecoveryStateMachine.transition(from: recovering, event: .recoveryFailed("Camera unavailable"))
                == .failed("Camera unavailable")
        )
    }
}

private struct FixedStorageCapacityProvider: StorageCapacityProviding {
    let availableCapacity: Int64

    func availableCapacity(at _: URL) throws -> Int64? {
        availableCapacity
    }
}

private struct FixedThermalStateProvider: ThermalStateProviding {
    let thermalState: DeviceThermalState
}
