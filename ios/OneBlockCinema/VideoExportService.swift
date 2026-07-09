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

nonisolated struct RenderIntertitleCue: Sendable, Equatable {
    let id: UUID
    let text: String
    let timelineStart: TimeInterval
    let duration: TimeInterval
}

nonisolated struct RenderPlan: Sendable, Equatable {
    let projectId: UUID?
    let aspectRatio: TemplateAspectRatio
    let outputDimensions: RenderDimensions
    let segments: [RenderSegment]
    let audioTracks: [ProjectAudioTrack]
    let titleCues: [RenderTitleCue]
    let intertitleCues: [RenderIntertitleCue]
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
            audioTracks: project.audioTracks,
            intertitles: project.intertitles,
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
            audioTracks: [],
            intertitles: [],
            aspectRatio: .horizontal,
            pacingStyle: .rhythmic,
            editStyle: .standard,
            maxDuration: maxDuration
        )
    }

    private static func buildPlan(
        projectId: UUID?,
        clips: [FilmClip],
        audioTracks: [ProjectAudioTrack],
        intertitles: [IntertitleCard],
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
                audioTracks: audioTracks,
                titleCues: [],
                intertitleCues: [],
                totalDuration: 0,
                wasTrimmedToMaximumDuration: !clips.isEmpty || !intertitles.isEmpty,
                pacingStyle: pacingStyle,
                editStyle: editStyle
            )
        }

        var timelineEnd: TimeInterval = 0
        var segments: [RenderSegment] = []
        var intertitleCues: [RenderIntertitleCue] = []
        var trimmed = false
        var previousItemWasClip = false
        let cardsByPosition = Dictionary(grouping: intertitles) { card in
            min(max(card.position, 0), clips.count)
        }

        for position in 0...clips.count {
            for card in cardsByPosition[position, default: []] {
                let duration = min(card.duration, max(0, maxDuration - timelineEnd))
                guard duration > 0 else {
                    trimmed = true
                    break
                }
                intertitleCues.append(
                    RenderIntertitleCue(
                        id: card.id,
                        text: String(card.text.prefix(120)),
                        timelineStart: timelineEnd,
                        duration: duration
                    )
                )
                timelineEnd += duration
                previousItemWasClip = false
                if duration < card.duration || timelineEnd >= maxDuration {
                    trimmed = true
                    break
                }
            }
            if timelineEnd >= maxDuration { break }
            guard clips.indices.contains(position) else { continue }
            let clip = clips[position]
            guard clip.isMediaAvailable, clip.trimmedDuration > 0 else {
                previousItemWasClip = false
                continue
            }
            let fullDuration = clip.trimmedDuration
            let previousDuration = segments.last?.duration ?? 0
            let requestedTransition = clip.transitionStyle == .crossfade && previousItemWasClip
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
            previousItemWasClip = true

            if duration < fullDuration {
                trimmed = true
            }
            if timelineEnd >= maxDuration {
                trimmed = trimmed || position < clips.count - 1 || cardsByPosition[position + 1] != nil
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
            audioTracks: audioTracks,
            titleCues: titleCues,
            intertitleCues: intertitleCues,
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
        var audioParameters = audioTracks.map { AVMutableAudioMixInputParameters(track: $0) }
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
        extendVideoTracks(videoTracks, to: plan.totalDuration)
        try await insertProjectAudio(
            plan.audioTracks,
            into: composition,
            parameters: &audioParameters,
            timelineDuration: plan.totalDuration,
            muted: plan.editStyle == .silentFilm
        )
        var instructions = makeVideoInstructions(
            for: insertedSegments,
            intertitles: plan.intertitleCues
        )
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

    private static func extendVideoTracks(
        _ tracks: [AVMutableCompositionTrack],
        to duration: TimeInterval
    ) {
        let desiredEnd = CMTime(seconds: duration, preferredTimescale: 600)
        for track in tracks {
            let currentEnd = track.timeRange.end
            guard CMTimeCompare(currentEnd, desiredEnd) < 0 else { continue }
            track.insertEmptyTimeRange(
                CMTimeRange(start: currentEnd, duration: CMTimeSubtract(desiredEnd, currentEnd))
            )
        }
    }

    private static func insertProjectAudio(
        _ projectTracks: [ProjectAudioTrack],
        into composition: AVMutableComposition,
        parameters: inout [AVMutableAudioMixInputParameters],
        timelineDuration: TimeInterval,
        muted: Bool
    ) async throws {
        guard timelineDuration > 0 else { return }
        for projectTrack in projectTracks {
            guard FileManager.default.fileExists(atPath: projectTrack.fileURL.path) else {
                throw ExportError.missingAudio(projectTrack.kind)
            }
            let asset = AVURLAsset(url: projectTrack.fileURL)
            guard let source = try await asset.loadTracks(withMediaType: .audio).first else {
                throw ExportError.invalidAudio(projectTrack.kind)
            }
            guard let target = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { throw ExportError.trackCreationFailed }
            let assetDuration = max(0, CMTimeGetSeconds(try await asset.load(.duration)))
            guard assetDuration.isFinite, assetDuration > 0 else {
                throw ExportError.invalidAudio(projectTrack.kind)
            }
            let desiredVolume = Float(muted ? 0 : min(max(projectTrack.volume, 0), 1))
            let mix = AVMutableAudioMixInputParameters(track: target)
            mix.setVolume(desiredVolume, at: .zero)
            parameters.append(mix)

            var cursor: TimeInterval = 0
            repeat {
                let insertedDuration = min(assetDuration, timelineDuration - cursor)
                guard insertedDuration > 0 else { break }
                try target.insertTimeRange(
                    CMTimeRange(
                        start: .zero,
                        duration: CMTime(seconds: insertedDuration, preferredTimescale: 600)
                    ),
                    of: source,
                    at: CMTime(seconds: cursor, preferredTimescale: 600)
                )
                cursor += insertedDuration
            } while projectTrack.kind == .ambient && cursor < timelineDuration
        }
    }

    private static func makeVideoInstructions(
        for insertedSegments: [InsertedVideoSegment],
        intertitles: [RenderIntertitleCue]
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

        for cue in intertitles {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(
                start: CMTime(seconds: cue.timelineStart, preferredTimescale: 600),
                duration: CMTime(seconds: cue.duration, preferredTimescale: 600)
            )
            instruction.backgroundColor = CGColor(gray: 0.02, alpha: 1)
            instruction.layerInstructions = []
            instructions.append(instruction)
        }

        return instructions
    }

    private static func configureAnimationTool(
        for plan: RenderPlan,
        videoComposition: AVMutableVideoComposition
    ) {
        guard plan.editStyle == .silentFilm
            || !plan.titleCues.isEmpty
            || !plan.intertitleCues.isEmpty else { return }

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

        for cue in plan.intertitleCues {
            let backgroundLayer = CALayer()
            backgroundLayer.frame = frame
            backgroundLayer.backgroundColor = CGColor(gray: 0.02, alpha: 1)
            backgroundLayer.opacity = 0
            backgroundLayer.add(
                intertitleOpacityAnimation(start: cue.timelineStart, duration: cue.duration),
                forKey: "intertitle-background-\(cue.id.uuidString)"
            )
            parentLayer.addSublayer(backgroundLayer)

            let textLayer = CATextLayer()
            textLayer.string = cue.text
            textLayer.alignmentMode = .center
            textLayer.foregroundColor = CGColor(gray: 0.96, alpha: 1)
            textLayer.contentsScale = 2
            textLayer.fontSize = max(42, frame.width * 0.065)
            textLayer.isWrapped = true
            textLayer.frame = CGRect(
                x: frame.width * 0.1,
                y: frame.height * 0.32,
                width: frame.width * 0.8,
                height: frame.height * 0.36
            )
            textLayer.opacity = 0
            textLayer.add(
                intertitleOpacityAnimation(start: cue.timelineStart, duration: cue.duration),
                forKey: "intertitle-text-\(cue.id.uuidString)"
            )
            parentLayer.addSublayer(textLayer)
        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }

    private static func intertitleOpacityAnimation(
        start: TimeInterval,
        duration: TimeInterval
    ) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [0, 1, 1, 0]
        animation.keyTimes = [0, 0.001, 0.999, 1]
        animation.duration = max(0.1, duration)
        animation.beginTime = AVCoreAnimationBeginTimeAtZero + start
        animation.isRemovedOnCompletion = false
        animation.fillMode = .both
        return animation
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
    case missingAudio(ProjectAudioTrackKind)
    case invalidAudio(ProjectAudioTrackKind)
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
        case .missingAudio(let kind):
            "The \(kind.rawValue) audio file is missing. Replace or remove it in Assembly."
        case .invalidAudio(let kind):
            "The \(kind.rawValue) audio file is not readable. Replace it in Assembly."
        case .incompleteExport:
            "Export stopped because one or more clips could not be included."
        case .insufficientStorage(let required, let available):
            "Export needs about \(required) MB free, but only \(available) MB is available."
        case .exportFailed(let message):
            "Export failed: \(message)"
        }
    }
}
