import AVFoundation
import UIKit

actor VideoExportService {
    func exportAssembledVideo(clips: [FilmClip], pacingStyle: PacingStyle, editStyle: EditStyle) async throws -> URL {
        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.trackCreationFailed
        }

        var currentTime = CMTime.zero
        let transitionDuration = CMTime(seconds: pacingStyle.transitionDuration, preferredTimescale: 600)

        for clip in clips {
            let asset = AVURLAsset(url: clip.fileURL)

            do {
                let duration = try await asset.load(.duration)
                let tracks = try await asset.loadTracks(withMediaType: .video)

                if let sourceVideoTrack = tracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)
                }

                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                if let sourceAudioTrack = audioTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
                }

                currentTime = CMTimeAdd(currentTime, duration)
                currentTime = CMTimeAdd(currentTime, transitionDuration)
            } catch {
                continue
            }
        }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("OneBlockCinema_\(UUID().uuidString).mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw ExportError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }

        return outputURL
    }
}

nonisolated enum ExportError: Error, LocalizedError, Sendable {
    case trackCreationFailed
    case exportSessionFailed
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .trackCreationFailed: "Failed to create video tracks"
        case .exportSessionFailed: "Failed to create export session"
        case .exportFailed(let message): "Export failed: \(message)"
        }
    }
}
