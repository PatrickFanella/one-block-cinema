@preconcurrency import AVFoundation
import CoreImage
import Foundation

nonisolated struct CinemaCompositionSegment: Sendable {
    let segment: RenderSegment
    let trackID: CMPersistentTrackID
    let transform: CGAffineTransform
}

final nonisolated class CinemaCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let segments: [CinemaCompositionSegment]
    let plan: RenderPlan
    let titleImages: [UUID: CGImage]
    let intertitleImages: [UUID: CGImage]

    init(plan: RenderPlan, segments: [CinemaCompositionSegment]) {
        self.plan = plan
        self.segments = segments
        timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: plan.totalDuration, preferredTimescale: 600)
        )
        requiredSourceTrackIDs = Array(Set(segments.map(\.trackID))).map { NSNumber(value: $0) }
        let size = plan.outputDimensions.size
        let titleRect = CGRect(x: size.width * 0.08, y: size.height * 0.08, width: size.width * 0.84, height: size.height * 0.12)
        titleImages = Dictionary(uniqueKeysWithValues: plan.titleCues.compactMap { cue in
            RenderOverlayImageFactory.make(
                size: size,
                backgroundColor: CGColor(gray: 0, alpha: 0.72),
                backgroundRect: titleRect,
                cornerRadius: max(10, size.width * 0.012),
                text: cue.text,
                textColor: CGColor(gray: 1, alpha: 1),
                fontSize: max(28, size.width * 0.045),
                textRect: titleRect.insetBy(dx: size.width * 0.025, dy: size.height * 0.015)
            ).map { (cue.clipId, $0) }
        })
        let intertitleRect = CGRect(x: size.width * 0.1, y: size.height * 0.32, width: size.width * 0.8, height: size.height * 0.36)
        intertitleImages = Dictionary(uniqueKeysWithValues: plan.intertitleCues.compactMap { cue in
            RenderOverlayImageFactory.make(
                size: size,
                backgroundColor: CGColor(gray: 0.02, alpha: 1),
                text: cue.text,
                textColor: CGColor(gray: 0.96, alpha: 1),
                fontSize: max(42, size.width * 0.065),
                textRect: intertitleRect
            ).map { (cue.id, $0) }
        })
        super.init()
    }
}

final nonisolated class CinemaVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    let sourcePixelBufferAttributes: [String: any Sendable]? = [
        kCVPixelBufferPixelFormatTypeKey as String: [
            kCVPixelFormatType_32BGRA,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        ],
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ]
    // swiftlint:disable:next identifier_name
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferMetalCompatibilityKey as String: true
    ]

    private let queue = DispatchQueue(label: "app.oneblockcinema.video-compositor", qos: .userInitiated)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let outputColorSpace = CGColorSpace(name: CGColorSpace.itur_709) ?? CGColorSpaceCreateDeviceRGB()
    private var renderContext: AVVideoCompositionRenderContext?
    private var generation = 0

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        queue.sync {
            renderContext = newRenderContext
            generation += 1
        }
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        let requestGeneration = generation
        queue.async { [self] in
            guard requestGeneration == generation else {
                request.finishCancelledRequest()
                return
            }
            guard let instruction = request.videoCompositionInstruction as? CinemaCompositionInstruction,
                  let destination = renderContext?.newPixelBuffer()
            else {
                request.finish(with: CompositorError.invalidInstruction)
                return
            }
            let image = compose(request: request, instruction: instruction)
            context.render(
                image,
                to: destination,
                bounds: CGRect(origin: .zero, size: instruction.plan.outputDimensions.size),
                colorSpace: outputColorSpace
            )
            request.finish(withComposedVideoFrame: destination)
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        queue.async { [self] in generation += 1 }
    }

    private func compose(
        request: AVAsynchronousVideoCompositionRequest,
        instruction: CinemaCompositionInstruction
    ) -> CIImage {
        let seconds = CMTimeGetSeconds(request.compositionTime)
        let bounds = CGRect(origin: .zero, size: instruction.plan.outputDimensions.size)
        if let cue = instruction.plan.intertitleCues.first(where: { $0.contains(seconds) }),
           let image = instruction.intertitleImages[cue.id]
        {
            return CIImage(cgImage: image).cropped(to: bounds)
        }

        let active = instruction.segments.filter { $0.segment.contains(seconds) }
        var result = CIImage(color: .black).cropped(to: bounds)
        for item in active {
            guard let buffer = request.sourceFrame(byTrackID: item.trackID) else { continue }
            var image = CIImage(cvPixelBuffer: buffer, options: [.toneMapHDRtoSDR: true])
                .transformed(by: item.transform)
                .cropped(to: bounds)
            if instruction.plan.editStyle == .silentFilm {
                image = image
                    .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.15])
                    .applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.78])
            }
            let opacity = item.segment.transitionOpacity(at: seconds)
            result = image.applyingOpacity(opacity).composited(over: result)
        }

        for cue in instruction.plan.titleCues where cue.contains(seconds) {
            guard let overlay = instruction.titleImages[cue.clipId] else { continue }
            let opacity = cue.opacity(at: seconds)
            result = CIImage(cgImage: overlay).applyingOpacity(opacity).composited(over: result)
        }
        return result.cropped(to: bounds)
    }
}

private nonisolated enum CompositorError: Error {
    case invalidInstruction
}

private extension RenderSegment {
    func contains(_ seconds: TimeInterval) -> Bool {
        seconds >= timelineStart && seconds < timelineStart + duration
    }

    func transitionOpacity(at seconds: TimeInterval) -> CGFloat {
        guard transitionDuration > 0, seconds < timelineStart + transitionDuration else { return 1 }
        return CGFloat(min(max((seconds - timelineStart) / transitionDuration, 0), 1))
    }
}

private extension RenderTitleCue {
    func contains(_ seconds: TimeInterval) -> Bool {
        seconds >= timelineStart && seconds < timelineStart + duration
    }

    func opacity(at seconds: TimeInterval) -> CGFloat {
        let progress = min(max((seconds - timelineStart) / max(duration, 0.1), 0), 1)
        if progress < 0.08 {
            return CGFloat(progress / 0.08)
        }
        if progress > 0.82 {
            return CGFloat((1 - progress) / 0.18)
        }
        return 1
    }
}

private extension RenderIntertitleCue {
    func contains(_ seconds: TimeInterval) -> Bool {
        seconds >= timelineStart && seconds < timelineStart + duration
    }
}

private extension CIImage {
    func applyingOpacity(_ opacity: CGFloat) -> CIImage {
        let amount = max(0, min(opacity, 1))
        return applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputRVector": CIVector(x: amount, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: amount, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: amount, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: amount)
            ]
        )
    }
}
