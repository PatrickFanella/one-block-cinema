import AVFoundation
import UIKit

actor VideoExportService {
    func exportAssembledVideo(
        clips: [FilmClip],
        pacingStyle: PacingStyle,
        editStyle: EditStyle,
        progressHandler: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        _ = pacingStyle
        _ = editStyle

        let plan = VideoExportLimits.plan(for: clips)
        guard !plan.segments.isEmpty else {
            throw ExportError.noExportableClips
        }

        let composition = AVMutableComposition()

        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.trackCreationFailed
        }

        var currentTime = CMTime.zero
        var insertedSegmentCount = 0

        for segment in plan.segments {
            let asset = AVURLAsset(url: segment.clip.fileURL)

            do {
                let assetDuration = try await asset.load(.duration)
                let guardedDuration = CMTime(seconds: segment.duration, preferredTimescale: 600)
                let duration = CMTimeMinimum(assetDuration, guardedDuration)
                let tracks = try await asset.loadTracks(withMediaType: .video)

                guard let sourceVideoTrack = tracks.first else {
                    throw ExportError.clipLoadFailed("Imported clip has no readable video track.")
                }

                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)

                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                if let sourceAudioTrack = audioTracks.first {
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
                }

                currentTime = CMTimeAdd(currentTime, duration)
                insertedSegmentCount += 1
            } catch {
                throw ExportError.clipLoadFailed(error.localizedDescription)
            }
        }

        guard insertedSegmentCount > 0 else {
            throw ExportError.noExportableClips
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

        progressHandler(0.1)

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw ExportError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }

        progressHandler(1)
        return outputURL
    }
}

nonisolated struct VideoExportSegment: Sendable, Equatable {
    let clip: FilmClip
    let duration: TimeInterval
}

nonisolated struct VideoExportPlan: Sendable, Equatable {
    let segments: [VideoExportSegment]
    let totalDuration: TimeInterval
    let wasTrimmedToMaximumDuration: Bool
}

nonisolated enum VideoExportLimits {
    static let maximumDuration: TimeInterval = 180

    static func plan(for clips: [FilmClip], maxDuration: TimeInterval = maximumDuration) -> VideoExportPlan {
        guard maxDuration > 0 else {
            return VideoExportPlan(segments: [], totalDuration: 0, wasTrimmedToMaximumDuration: !clips.isEmpty)
        }

        var remainingDuration = maxDuration
        var segments: [VideoExportSegment] = []
        var trimmed = false

        for clip in clips {
            guard clip.duration > 0 else { continue }

            if clip.duration <= remainingDuration {
                segments.append(VideoExportSegment(clip: clip, duration: clip.duration))
                remainingDuration -= clip.duration
            } else if remainingDuration > 0 {
                segments.append(VideoExportSegment(clip: clip, duration: remainingDuration))
                remainingDuration = 0
                trimmed = true
            } else {
                trimmed = true
            }
        }

        let totalDuration = segments.reduce(0) { $0 + $1.duration }
        return VideoExportPlan(
            segments: segments,
            totalDuration: totalDuration,
            wasTrimmedToMaximumDuration: trimmed || clips.contains { $0.duration > maxDuration }
        )
    }
}

nonisolated enum ExportError: Error, LocalizedError, Sendable {
    case noExportableClips
    case trackCreationFailed
    case exportSessionFailed
    case clipLoadFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noExportableClips: "Add at least one imported video clip before exporting."
        case .trackCreationFailed: "Failed to create video tracks"
        case .exportSessionFailed: "Failed to create export session"
        case .clipLoadFailed(let message): "Could not read imported clip: \(message)"
        case .exportFailed(let message): "Export failed: \(message)"
        }
    }
}
