import AVFoundation
import SwiftUI
import UIKit

@Observable
@MainActor
final class VoiceoverRecorder {
    enum State: Equatable {
        case idle
        case requestingPermission
        case recording
        case ready
        case denied
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var recordedURL: URL?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start() async {
        guard state != .recording else { return }
        state = .requestingPermission
        guard await requestPermission() else {
            state = .denied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("OneBlockCinemaVoiceover_\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else { throw VoiceoverRecorderError.couldNotStart }
            self.recorder = recorder
            recordedURL = url
            elapsed = 0
            state = .recording
            startTimer()
        } catch {
            state = .failed(error.localizedDescription)
            deactivateSession()
        }
    }

    func stop() {
        guard state == .recording else { return }
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        state = .ready
        deactivateSession()
    }

    func discard() {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        if let recordedURL {
            try? FileManager.default.removeItem(at: recordedURL)
        }
        recordedURL = nil
        elapsed = 0
        if state != .denied {
            state = .idle
        }
        deactivateSession()
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, state == .recording else { return }
                elapsed = recorder?.currentTime ?? elapsed
                if elapsed >= VideoExportLimits.maximumDuration {
                    stop()
                }
            }
        }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

nonisolated enum VoiceoverRecorderError: LocalizedError, Sendable {
    case couldNotStart

    var errorDescription: String? {
        "Voiceover recording could not start."
    }
}

struct VoiceoverRecorderSheet: View {
    let onUseRecording: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var recorder = VoiceoverRecorder()
    @State private var didUseRecording = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: recorder.state == .recording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(recorder.state == .recording ? .red : CinemaColors.amber)
                    .accessibilityHidden(true)

                Text(stateTitle)
                    .font(.system(.title2, design: .serif, weight: .semibold))

                Text(formattedDuration(recorder.elapsed))
                    .font(.title3.monospacedDigit())
                    .accessibilityLabel("Recorded time \(formattedDuration(recorder.elapsed))")

                stateControls

                Text("Voiceover is recorded locally and stays with this draft. Recording stops automatically at three minutes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Voiceover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onDisappear {
            if !didUseRecording {
                recorder.discard()
            }
        }
    }

    @ViewBuilder
    private var stateControls: some View {
        switch recorder.state {
        case .idle, .failed:
            Button {
                Task { await recorder.start() }
            } label: {
                Label("Start Recording", systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        case .requestingPermission:
            ProgressView("Checking microphone access…")
        case .recording:
            Button {
                recorder.stop()
            } label: {
                Label("Stop Recording", systemImage: "stop.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        case .ready:
            HStack {
                Button("Record Again") { recorder.discard() }
                    .buttonStyle(.bordered)
                Button("Use Voiceover") {
                    guard let url = recorder.recordedURL else { return }
                    didUseRecording = true
                    onUseRecording(url)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(CinemaColors.amber)
            }
        case .denied:
            VStack(spacing: 12) {
                Text("Microphone access is off. Enable it in Settings, or import an existing audio file.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var stateTitle: String {
        switch recorder.state {
        case .idle: "Ready to record"
        case .requestingPermission: "Preparing microphone"
        case .recording: "Recording"
        case .ready: "Voiceover ready"
        case .denied: "Microphone access needed"
        case let .failed(message): message
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)
    }
}
