import AVFoundation
import CoreGraphics
import Foundation
import QuartzCore

nonisolated struct RenderDimensions: Sendable, Equatable, Hashable {
    let width: Int
    let height: Int

    var size: CGSize { CGSize(width: width, height: height) }

    static func fullHD(for aspectRatio: TemplateAspectRatio) -> RenderDimensions {
        switch aspectRatio {
        case .vertical:
            RenderDimensions(width: 1080, height: 1920)
        case .square:
            RenderDimensions(width: 1080, height: 1080)
        case .horizontal:
            RenderDimensions(width: 1920, height: 1080)
        case .portrait:
            RenderDimensions(width: 1080, height: 1350)
        }
    }
}

nonisolated struct RenderSegment: Sendable, Equatable {
    let clip: FilmClip
    let sourceStart: TimeInterval
    let duration: TimeInterval
    let timelineStart: TimeInterval
    let transitionDuration: TimeInterval
}

nonisolated struct RenderTitleCue: Sendable, Equatable {
    let clipId: UUID
    let text: String
    let timelineStart: TimeInterval
    let duration: TimeInterval
}

nonisolated struct RenderPlan: Sendable, Equatable {
    let projectId: UUID?
    let aspectRatio: TemplateAspectRatio
    let outputDimensions: RenderDimensions
    let segments: [RenderSegment]
    let titleCues: [RenderTitleCue]
    let totalDuration: TimeInterval
    let wasTrimmedToMaximumDuration: Bool
    let pacingStyle: PacingStyle
    let editStyle: EditStyle
}

typealias VideoExportSegment = RenderSegment
typealias VideoExportPlan = RenderPlan

nonisolated enum VideoExportLimits {
    static let maximumDuration: TimeInterval = 180

    static func plan(for project: FilmProject, maxDuration: TimeInterval = maximumDuration) -> RenderPlan {
        buildPlan(
            projectId: project.id,
            clips: project.clipsInEditOrder,
            aspectRatio: project.aspectRatio ?? .horizontal,
            pacingStyle: project.pacingStyle,
            editStyle: project.editStyle,
            maxDuration: maxDuration
        )
    }

    static func plan(for clips: [FilmClip], maxDuration: TimeInterval = maximumDuration) -> RenderPlan {
        buildPlan(
            projectId: nil,
            clips: clips,
            aspectRatio: .horizontal,
            pacingStyle: .rhythmic,
            editStyle: .standard,
            maxDuration: maxDuration
        )
    }

    private static func buildPlan(
        projectId: UUID?,
        clips: [FilmClip],
        aspectRatio: TemplateAspectRatio,
        pacingStyle: PacingStyle,
        editStyle: EditStyle,
        maxDuration: TimeInterval
    ) -> RenderPlan {
        guard maxDuration > 0 else {
            return RenderPlan(
                projectId: projectId,
                aspectRatio: aspectRatio,
                outputDimensions: .fullHD(for: aspectRatio),
                segments: [],
                titleCues: [],
                totalDuration: 0,
                wasTrimmedToMaximumDuration: !clips.isEmpty,
                pacingStyle: pacingStyle,
                editStyle: editStyle
            )
        }

        let exportableClips = clips.filter { $0.isMediaAvailable && $0.trimmedDuration > 0 }
        var timelineEnd: TimeInterval = 0
        var segments: [RenderSegment] = []
        var trimmed = false

        for (index, clip) in exportableClips.enumerated() {
            let fullDuration = clip.trimmedDuration
            let previousDuration = segments.last?.duration ?? 0
            let requestedTransition = clip.transitionStyle == .crossfade && !segments.isEmpty
                ? pacingStyle.transitionDuration
                : 0
            var transitionDuration = min(requestedTransition, previousDuration / 2, fullDuration / 2)
            var timelineStart = max(0, timelineEnd - transitionDuration)
            var duration = min(fullDuration, max(0, maxDuration - timelineStart))

            transitionDuration = min(transitionDuration, duration / 2)
            timelineStart = max(0, timelineEnd - transitionDuration)
            duration = min(fullDuration, max(0, maxDuration - timelineStart))
            guard duration > 0 else {
                trimmed = true
                break
            }

            segments.append(
                RenderSegment(
                    clip: clip,
                    sourceStart: clip.effectiveTrimStart,
                    duration: duration,
                    timelineStart: timelineStart,
                    transitionDuration: transitionDuration
                )
            )
            timelineEnd = timelineStart + duration

            if duration < fullDuration {
                trimmed = true
            }
            if timelineEnd >= maxDuration {
                trimmed = trimmed || index < exportableClips.count - 1
                break
            }
        }

        let titleCues = segments.compactMap { segment -> RenderTitleCue? in
            let title = segment.clip.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard segment.clip.showTitle, !title.isEmpty else { return nil }
            return RenderTitleCue(
                clipId: segment.clip.id,
                text: String(title.prefix(80)),
                timelineStart: segment.timelineStart,
                duration: min(3, segment.duration)
            )
        }

        return RenderPlan(
            projectId: projectId,
            aspectRatio: aspectRatio,
            outputDimensions: .fullHD(for: aspectRatio),
            segments: segments,
            titleCues: titleCues,
            totalDuration: timelineEnd,
            wasTrimmedToMaximumDuration: trimmed,
            pacingStyle: pacingStyle,
            editStyle: editStyle
        )
    }
}

nonisolated struct PreparedRender: @unchecked Sendable {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let audioMix: AVAudioMix?

    @MainActor func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        item.audioMix = audioMix
        return item
    }
}

nonisolated enum RenderCompositionBuilder {
    private struct InsertedVideoSegment {
        let segment: RenderSegment
        let track: AVMutableCompositionTrack
        let transform: CGAffineTransform
    }

    static func build(plan: RenderPlan) async throws -> PreparedRender {
        guard !plan.segments.isEmpty else {
            throw ExportError.noExportableClips
        }

        let composition = AVMutableComposition()
        let videoTracks = (0..<2).compactMap { _ in
            composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }
        guard videoTracks.count == 2 else {
            throw ExportError.trackCreationFailed
        }
        let audioTracks = (0..<2).compactMap { _ in
            composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = plan.outputDimensions.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        let audioParameters = audioTracks.map { AVMutableAudioMixInputParameters(track: $0) }
        var insertedSegments: [InsertedVideoSegment] = []

        for (index, segment) in plan.segments.enumerated() {
            let clip = segment.clip
            guard FileManager.default.fileExists(atPath: clip.fileURL.path) else {
                throw ExportError.missingClip(clip.fileURL.lastPathComponent)
            }

            let asset = AVURLAsset(url: clip.fileURL)
            let assetDuration = try await asset.load(.duration)
            let sourceStart = CMTime(seconds: segment.sourceStart, preferredTimescale: 600)
            let plannedDuration = CMTime(seconds: segment.duration, preferredTimescale: 600)
            let availableDuration = CMTimeSubtract(assetDuration, sourceStart)
            let duration = CMTimeMinimum(plannedDuration, availableDuration)
            guard duration.isValid, CMTimeGetSeconds(duration) > 0 else {
                throw ExportError.invalidClip(clip.fileURL.lastPathComponent)
            }

            guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw ExportError.invalidClip(clip.fileURL.lastPathComponent)
            }
            let timeRange = CMTimeRange(start: sourceStart, duration: duration)
            let insertionTime = CMTime(seconds: segment.timelineStart, preferredTimescale: 600)
            let trackIndex = index % videoTracks.count
            let videoTrack = videoTracks[trackIndex]
            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertionTime)

            if audioTracks.indices.contains(trackIndex),
               let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                let audioTrack = audioTracks[trackIndex]
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertionTime)
            }

            let volume = Float(plan.editStyle == .silentFilm ? 0 : min(max(clip.volume, 0), 1))
            if audioParameters.indices.contains(trackIndex) {
                let parameters = audioParameters[trackIndex]
                if segment.transitionDuration > 0 {
                    let transitionRange = CMTimeRange(
                        start: insertionTime,
                        duration: CMTime(seconds: segment.transitionDuration, preferredTimescale: 600)
                    )
                    parameters.setVolume(0, at: insertionTime)
                    parameters.setVolumeRamp(fromStartVolume: 0, toEndVolume: volume, timeRange: transitionRange)
                    if index > 0 {
                        let previousIndex = (index - 1) % audioParameters.count
                        let previousVolume = Float(
                            plan.editStyle == .silentFilm
                                ? 0
                                : min(max(plan.segments[index - 1].clip.volume, 0), 1)
                        )
                        audioParameters[previousIndex].setVolumeRamp(
                            fromStartVolume: previousVolume,
                            toEndVolume: 0,
                            timeRange: transitionRange
                        )
                    }
                } else {
                    parameters.setVolume(volume, at: insertionTime)
                }
            }

            let naturalSize = try await sourceVideoTrack.load(.naturalSize)
            let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
            insertedSegments.append(
                InsertedVideoSegment(
                    segment: segment,
                    track: videoTrack,
                    transform: normalizedTransform(
                        naturalSize: naturalSize,
                        preferredTransform: preferredTransform,
                        renderSize: plan.outputDimensions.size
                    )
                )
            )
        }

        guard insertedSegments.count == plan.segments.count else {
            throw ExportError.incompleteExport
        }
        var instructions = makeVideoInstructions(for: insertedSegments)
        instructions.sort { CMTimeCompare($0.timeRange.start, $1.timeRange.start) < 0 }
        guard !instructions.isEmpty else { throw ExportError.incompleteExport }
        videoComposition.instructions = instructions
        configureAnimationTool(for: plan, videoComposition: videoComposition)
        let audioMix: AVAudioMix?
        if audioParameters.isEmpty {
            audioMix = nil
        } else {
            let mix = AVMutableAudioMix()
            mix.inputParameters = audioParameters
            audioMix = mix
        }
        return PreparedRender(composition: composition, videoComposition: videoComposition, audioMix: audioMix)
    }

    private static func makeVideoInstructions(
        for insertedSegments: [InsertedVideoSegment]
    ) -> [AVMutableVideoCompositionInstruction] {
        var instructions: [AVMutableVideoCompositionInstruction] = []

        for (index, inserted) in insertedSegments.enumerated() {
            let segment = inserted.segment
            let nextTransition = insertedSegments.indices.contains(index + 1)
                ? insertedSegments[index + 1].segment.transitionDuration
                : 0
            let passStart = segment.timelineStart + segment.transitionDuration
            let passEnd = segment.timelineStart + segment.duration - nextTransition
            if passEnd - passStart > 0.001 {
                let start = CMTime(seconds: passStart, preferredTimescale: 600)
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(
                    start: start,
                    duration: CMTime(seconds: passEnd - passStart, preferredTimescale: 600)
                )
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: inserted.track)
                layer.setTransform(inserted.transform, at: start)
                instruction.layerInstructions = [layer]
                instructions.append(instruction)
            }

            guard index > 0, segment.transitionDuration > 0 else { continue }
            let outgoing = insertedSegments[index - 1]
            let transitionStart = CMTime(seconds: segment.timelineStart, preferredTimescale: 600)
            let transitionRange = CMTimeRange(
                start: transitionStart,
                duration: CMTime(seconds: segment.transitionDuration, preferredTimescale: 600)
            )
            let outgoingLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: outgoing.track)
            outgoingLayer.setTransform(outgoing.transform, at: transitionStart)
            outgoingLayer.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: transitionRange)
            let incomingLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: inserted.track)
            incomingLayer.setTransform(inserted.transform, at: transitionStart)
            incomingLayer.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: 1, timeRange: transitionRange)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = transitionRange
            instruction.layerInstructions = [outgoingLayer, incomingLayer]
            instructions.append(instruction)
        }

        return instructions
    }

    private static func configureAnimationTool(
        for plan: RenderPlan,
        videoComposition: AVMutableVideoComposition
    ) {
        guard plan.editStyle == .silentFilm || !plan.titleCues.isEmpty else { return }

        let frame = CGRect(origin: .zero, size: plan.outputDimensions.size)
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = frame
        videoLayer.frame = frame
        parentLayer.addSublayer(videoLayer)

        if plan.editStyle == .silentFilm {
            let tintLayer = CALayer()
            tintLayer.frame = frame
            tintLayer.backgroundColor = CGColor(red: 0.42, green: 0.28, blue: 0.08, alpha: 0.18)
            parentLayer.addSublayer(tintLayer)
        }

        for cue in plan.titleCues {
            let titleLayer = CATextLayer()
            titleLayer.string = cue.text
            titleLayer.alignmentMode = .center
            titleLayer.foregroundColor = CGColor(gray: 1, alpha: 1)
            titleLayer.backgroundColor = CGColor(gray: 0, alpha: 0.72)
            titleLayer.cornerRadius = max(10, frame.width * 0.012)
            titleLayer.contentsScale = 2
            titleLayer.fontSize = max(28, frame.width * 0.045)
            titleLayer.isWrapped = true
            titleLayer.frame = CGRect(
                x: frame.width * 0.08,
                y: frame.height * 0.08,
                width: frame.width * 0.84,
                height: frame.height * 0.12
            )
            titleLayer.opacity = 0

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0, 1, 1, 0]
            opacity.keyTimes = [0, 0.08, 0.82, 1]
            opacity.duration = max(0.1, cue.duration)
            opacity.beginTime = AVCoreAnimationBeginTimeAtZero + cue.timelineStart
            opacity.isRemovedOnCompletion = false
            opacity.fillMode = .both
            titleLayer.add(opacity, forKey: "title-opacity-\(cue.clipId.uuidString)")
            parentLayer.addSublayer(titleLayer)
        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }

    static func normalizedTransform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        renderSize: CGSize
    ) -> CGAffineTransform {
        let sourceRect = CGRect(origin: .zero, size: naturalSize)
        let orientedRect = sourceRect.applying(preferredTransform).standardized
        guard orientedRect.width > 0, orientedRect.height > 0 else { return preferredTransform }

        let scale = max(renderSize.width / orientedRect.width, renderSize.height / orientedRect.height)
        let scaledTransform = preferredTransform.concatenating(
            CGAffineTransform(scaleX: scale, y: scale)
        )
        let scaledRect = sourceRect.applying(scaledTransform).standardized
        let translation = CGAffineTransform(
            translationX: renderSize.width / 2 - scaledRect.midX,
            y: renderSize.height / 2 - scaledRect.midY
        )
        return scaledTransform.concatenating(translation)
    }
}

actor VideoExportService: RenderService {
    private var activeExportSession: AVAssetExportSession?

    func makePlan(for project: FilmProject) async throws -> RenderPlan {
        VideoExportLimits.plan(for: project)
    }

    func render(
        plan: RenderPlan,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        try checkAvailableDiskSpace(for: plan)
        progress(0.02)
        let prepared = try await RenderCompositionBuilder.build(plan: plan)
        progress(0.1)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneBlockCinema_\(UUID().uuidString).mp4")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(
            asset: prepared.composition,
            presetName: AVAssetExportPreset1920x1080
        ) else {
            throw ExportError.exportSessionFailed
        }
        exportSession.videoComposition = prepared.videoComposition
        exportSession.audioMix = prepared.audioMix
        exportSession.shouldOptimizeForNetworkUse = true
        activeExportSession = exportSession

        let progressTask = Task {
            for await state in exportSession.states(updateInterval: 0.1) {
                guard !Task.isCancelled else { return }
                if case .exporting(let exportProgress) = state {
                    progress(0.1 + exportProgress.fractionCompleted * 0.9)
                }
            }
        }
        defer {
            progressTask.cancel()
            activeExportSession = nil
        }

        do {
            try await exportSession.export(to: outputURL, as: .mp4)
        } catch is CancellationError {
            try? FileManager.default.removeItem(at: outputURL)
            throw CancellationError()
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw ExportError.exportFailed(error.localizedDescription)
        }

        progress(1)
        return outputURL
    }

    func cancelCurrentRender() async {
        activeExportSession?.cancelExport()
    }

    private func checkAvailableDiskSpace(for plan: RenderPlan) throws {
        let values = try FileManager.default.temporaryDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        guard let available = values.volumeAvailableCapacityForImportantUsage else { return }
        let minimumBytes = max(Int64(100 * 1_024 * 1_024), Int64(plan.totalDuration * 4 * 1_024 * 1_024))
        guard available >= minimumBytes else {
            throw ExportError.insufficientStorage(
                requiredMegabytes: Int(minimumBytes / 1_024 / 1_024),
                availableMegabytes: Int(available / 1_024 / 1_024)
            )
        }
    }
}

nonisolated enum ExportError: Error, LocalizedError, Sendable {
    case noExportableClips
    case trackCreationFailed
    case exportSessionFailed
    case missingClip(String)
    case invalidClip(String)
    case incompleteExport
    case insufficientStorage(requiredMegabytes: Int, availableMegabytes: Int)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noExportableClips:
            "Add at least one imported video clip before exporting."
        case .trackCreationFailed:
            "Failed to create video tracks."
        case .exportSessionFailed:
            "Failed to create an H.264 export session."
        case .missingClip(let name):
            "Missing clip file: \(name)"
        case .invalidClip(let name):
            "Clip is not readable video: \(name)"
        case .incompleteExport:
            "Export stopped because one or more clips could not be included."
        case .insufficientStorage(let required, let available):
            "Export needs about \(required) MB free, but only \(available) MB is available."
        case .exportFailed(let message):
            "Export failed: \(message)"
        }
    }
}
