import AVFoundation
import Foundation
@testable import OneBlockCinema
import Testing

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

        #expect(outputURL.pathExtension == "mp4")
        #expect(fileSize > 1000)
        #expect(abs(duration - plan.totalDuration) < 0.15)
        #expect(naturalSize == CGSize(width: 1920, height: 1080))
        #expect(!audioTracks.isEmpty)
        #expect(plan.intertitleCues.count == 1)
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
        frameRate: Int32 = 12
    ) async throws -> URL {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height)
            ]
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
        let frameCount = max(1, Int(ceil(duration * Double(frameRate))))

        for frame in 0 ..< frameCount {
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
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: frameRate)) else {
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
}

private enum MediaFixtureError: Error {
    case cannotCreateVideo
    case cannotCreatePixelBuffer
    case cannotCreateAudio
}
