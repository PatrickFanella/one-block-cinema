import AVFoundation
import Foundation
@testable import OneBlockCinema
import Testing
import VideoToolbox

@Suite(.serialized)
struct MediaRenderIntegrationTests {
    @Test func exportsMixedOrientationVideoIntertitleAndProjectAudio() async throws {
        let directory = try MediaFixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let landscapeURL = try await MediaFixtureFactory.makeVideo(
            at: directory.appendingPathComponent("landscape.mp4"),
            size: CGSize(width: 640, height: 360),
            duration: 1,
            color: 0xFF19_26CC
        )
        let portraitURL = try await MediaFixtureFactory.makeVideo(
            at: directory.appendingPathComponent("portrait-silent.mp4"),
            size: CGSize(width: 360, height: 640),
            duration: 1,
            color: 0xFFCC_5919
        )
        let ambientURL = try MediaFixtureFactory.makeAudio(
            at: directory.appendingPathComponent("ambient.caf"),
            duration: 0.4
        )
        let first = FilmClip(
            promptId: UUID(),
            fileURL: landscapeURL,
            duration: 1,
            showTitle: true,
            titleText: "Opening"
        )
        let second = FilmClip(
            promptId: UUID(),
            fileURL: portraitURL,
            duration: 1,
            volume: 0.6
        )
        let project = FilmSession(
            theme: .documentary,
            aspectRatio: .horizontal,
            clips: [first, second],
            audioTracks: [
                ProjectAudioTrack(
                    kind: .ambient,
                    fileURL: ambientURL,
                    duration: 0.4,
                    volume: 0.2
                )
            ],
            intertitles: [IntertitleCard(text: "Meanwhile", duration: 0.5, position: 1)],
            clipOrder: [first.id, second.id]
        )
        let plan = VideoExportLimits.plan(for: project)
        let outputURL = try await VideoExportService().render(plan: plan)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let asset = AVURLAsset(url: outputURL)
        let duration = try await CMTimeGetSeconds(asset.load(.duration))
        let videoTrack = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let fileSize = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let titleFrame = try await MediaFixtureFactory.frame(from: asset, at: 0.5)
        let intertitleFrame = try await MediaFixtureFactory.frame(from: asset, at: 1.25)
        let titleBand = MediaFixtureFactory.averageRGB(
            titleFrame,
            normalizedRect: CGRect(x: 0.08, y: 0.78, width: 0.84, height: 0.12)
        )
        let videoArea = MediaFixtureFactory.averageRGB(
            titleFrame,
            normalizedRect: CGRect(x: 0.08, y: 0.3, width: 0.84, height: 0.2)
        )
        let intertitleArea = MediaFixtureFactory.averageRGB(
            intertitleFrame,
            normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1)
        )

        #expect(outputURL.pathExtension == "mp4")
        #expect(fileSize > 1000)
        #expect(abs(duration - plan.totalDuration) < 0.15)
        #expect(naturalSize == CGSize(width: 1920, height: 1080))
        #expect(!audioTracks.isEmpty)
        #expect(plan.intertitleCues.count == 1)
        #expect(titleBand.luminance < videoArea.luminance * 0.75)
        #expect(intertitleArea.luminance < 0.2)
    }

    @Test func rejectsCorruptMediaWithAnActionableFailure() async throws {
        let directory = try MediaFixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let corruptURL = directory.appendingPathComponent("corrupt.mp4")
        try Data("not a media file".utf8).write(to: corruptURL)
        let clip = FilmClip(promptId: UUID(), fileURL: corruptURL, duration: 1)

        do {
            _ = try await VideoExportService().render(plan: VideoExportLimits.plan(for: [clip]))
            Issue.record("Corrupt media unexpectedly rendered")
        } catch let error as ExportError {
            #expect(error.errorDescription?.contains("not readable") == true)
        }
    }

    @Test func normalizesHDRAndVariableFrameRateSourcesToRec709H264AtThirtyFPS() async throws {
        let directory = try MediaFixtureFactory.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let frameTimes: [TimeInterval] = [0, 1.0 / 24, 1.0 / 12, 0.18, 0.31, 0.47, 0.7]
        let sourceURL = try await MediaFixtureFactory.makeVideo(
            at: directory.appendingPathComponent("hdr-vfr.mov"),
            size: CGSize(width: 640, height: 360),
            duration: 0.8,
            color: 0xFFE8_9220,
            codec: .hevc,
            hdr: true,
            frameTimes: frameTimes
        )
        let clip = FilmClip(promptId: UUID(), fileURL: sourceURL, duration: 0.8)
        let outputURL = try await VideoExportService().render(plan: VideoExportLimits.plan(for: [clip]))
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let output = AVURLAsset(url: outputURL)
        let track = try #require(try await output.loadTracks(withMediaType: .video).first)
        let format = try #require(try await track.load(.formatDescriptions).first)
        let extensions = try #require(CMFormatDescriptionGetExtensions(format)) as NSDictionary

        #expect(CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_H264)
        #expect(try await abs(track.load(.nominalFrameRate) - 30) < 0.1)
        #expect(extensions[kCMFormatDescriptionExtension_ColorPrimaries] as? String == kCVImageBufferColorPrimaries_ITU_R_709_2 as String)
        #expect(extensions[kCMFormatDescriptionExtension_TransferFunction] as? String == kCVImageBufferTransferFunction_ITU_R_709_2 as String)
    }
}

private enum MediaFixtureFactory {
    static func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaRenderIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func makeVideo(
        at url: URL,
        size: CGSize,
        duration: TimeInterval,
        color: UInt32,
        frameRate: Int32 = 12,
        codec: AVVideoCodecType = .h264,
        hdr: Bool = false,
        frameTimes: [TimeInterval]? = nil
    ) async throws -> URL {
        var compression: [String: Any] = [:]
        if hdr {
            compression[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main10_AutoLevel
        }
        var settings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        if !compression.isEmpty {
            settings[AVVideoCompressionPropertiesKey] = compression
        }
        if hdr {
            settings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
            ]
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: url.pathExtension == "mov" ? .mov : .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: settings
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )
        guard writer.canAdd(input) else { throw MediaFixtureError.cannotCreateVideo }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? MediaFixtureError.cannotCreateVideo
        }
        writer.startSession(atSourceTime: .zero)
        let presentationTimes = frameTimes ?? (0 ..< max(1, Int(ceil(duration * Double(frameRate))))).map {
            Double($0) / Double(frameRate)
        }

        for seconds in presentationTimes {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            guard let pool = adaptor.pixelBufferPool else {
                throw MediaFixtureError.cannotCreatePixelBuffer
            }
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                  let buffer
            else {
                throw MediaFixtureError.cannotCreatePixelBuffer
            }
            fill(buffer, with: color)
            guard adaptor.append(buffer, withPresentationTime: CMTime(seconds: seconds, preferredTimescale: 600)) else {
                throw writer.error ?? MediaFixtureError.cannotCreateVideo
            }
        }

        writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 600))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? MediaFixtureError.cannotCreateVideo
        }
        return url
    }

    private static func fill(_ buffer: CVPixelBuffer, with color: UInt32) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0 ..< height {
            let pixels = baseAddress.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt32.self)
            for column in 0 ..< width {
                pixels[column] = color
            }
        }
    }

    static func makeAudio(at url: URL, duration: TimeInterval) throws -> URL {
        let sampleRate = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw MediaFixtureError.cannotCreateAudio
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0]
        else {
            throw MediaFixtureError.cannotCreateAudio
        }
        buffer.frameLength = frameCount
        for frame in 0 ..< Int(frameCount) {
            samples[frame] = Float(sin(2 * .pi * 220 * Double(frame) / sampleRate) * 0.08)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    static func frame(from asset: AVAsset, at seconds: TimeInterval) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
    }

    static func averageRGB(_ image: CGImage, normalizedRect: CGRect) -> RGBSample {
        let rect = CGRect(
            x: normalizedRect.minX * CGFloat(image.width),
            y: normalizedRect.minY * CGFloat(image.height),
            width: normalizedRect.width * CGFloat(image.width),
            height: normalizedRect.height * CGFloat(image.height)
        ).integral
        guard let cropped = image.cropping(to: rect) else { return .zero }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .zero }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return RGBSample(
            red: Double(pixel[0]) / 255,
            green: Double(pixel[1]) / 255,
            blue: Double(pixel[2]) / 255
        )
    }
}

private struct RGBSample {
    let red: Double
    let green: Double
    let blue: Double

    static let zero = RGBSample(red: 0, green: 0, blue: 0)

    var luminance: Double {
        red * 0.2126 + green * 0.7152 + blue * 0.0722
    }
}

private enum MediaFixtureError: Error {
    case cannotCreateVideo
    case cannotCreatePixelBuffer
    case cannotCreateAudio
}
