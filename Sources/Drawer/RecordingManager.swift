import AppKit
import Foundation
@preconcurrency import AVFoundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo

enum RecordingState {
    case idle
    case recording
}

class RecordingManager: NSObject {

    private(set) var state: RecordingState = .idle
    var onStateChanged: ((RecordingState) -> Void)?

    private let writingQueue = DispatchQueue(label: "com.drawer.recording", qos: .userInitiated)

    var makeWriter: (URL, AVFileType) throws -> any VideoWritable = { url, fileType in
        try AVAssetWriter(outputURL: url, fileType: fileType)
    }
    var makeStream: (SCContentFilter, SCStreamConfiguration, SCStreamDelegate?) -> any ScreenCaptureStreamable = { filter, config, delegate in
        SCStream(filter: filter, configuration: config, delegate: delegate)
    }

    private var assetWriter: (any VideoWritable)?
    private var videoInput: AVAssetWriterInput?
    private var videoAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?

    private var stream: (any ScreenCaptureStreamable)?
    private var captureSession: AVCaptureSession?

    private var recordingStartDate: Date = Date()
    private var sessionStarted = false
    private var pendingAudioBuffers: [CMSampleBuffer] = []

    // MARK: - Virtual chromakey state
    private(set) var isVirtualChromakey: Bool = false
    private var isAlphaChannel: Bool = false
    private var chromakeyTimer: DispatchSourceTimer?
    private weak var chromakeyDrawingView: DrawingView?
    private var chromakeyPixelBufferPool: CVPixelBufferPool?
    private var chromakeyFrameCount: Int = 0

    // MARK: - Public API

    func startRecording(
        filter: SCContentFilter,
        width: Int,
        height: Int,
        audioDevice: AVCaptureDevice?,
        outputURL: URL,
        sourceRect: CGRect? = nil
    ) async throws {
        guard state == .idle else { return }

        recordingStartDate = Date()
        sessionStarted = false
        pendingAudioBuffers = []

        // H.264 requires even dimensions
        let encodeWidth = (width / 2) * 2
        let encodeHeight = (height / 2) * 2

        let writer = try makeWriter(outputURL, .mp4)

        // Embed creation date as file-level metadata
        let creationItem = AVMutableMetadataItem()
        creationItem.identifier = .quickTimeMetadataCreationDate
        creationItem.value = ISO8601DateFormatter().string(from: recordingStartDate) as NSString
        writer.metadata = [creationItem]

        self.assetWriter = writer

        // Video input (H.264 with explicit Rec.709 color space)
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: encodeWidth,
                AVVideoHeightKey: encodeHeight,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                ],
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 8_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 60
                ] as [String: Any]
            ]
        )
        videoInput.expectsMediaDataInRealTime = true
        self.videoInput = videoInput

        // Pixel buffer adaptor: declares source pixel format to the encoder chain
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: encodeWidth,
                kCVPixelBufferHeightKey as String: encodeHeight,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
            ]
        )
        self.videoAdaptor = adaptor

        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        } else {
            print("RecordingManager: cannot add videoInput to writer")
        }

        // Audio input (AAC)
        if audioDevice != nil {
            let audioInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128_000
                ]
            )
            audioInput.expectsMediaDataInRealTime = true
            self.audioInput = audioInput
            if writer.canAdd(audioInput) { writer.add(audioInput) }
        }

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "RecordingManager", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "AVAssetWriter.startWriting() failed"])
        }

        // SCStream configuration — pixel format must match the adaptor's source format
        let config = SCStreamConfiguration()
        config.width = encodeWidth
        config.height = encodeHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 8
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        if let sourceRect = sourceRect {
            config.sourceRect = sourceRect
        }

        let scStream = makeStream(filter, config, self)
        self.stream = scStream
        try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: writingQueue)

        // Start audio capture BEFORE SCStream so it warms up in parallel
        if let audioDevice = audioDevice {
            startAudioCapture(device: audioDevice)
        }
        try await scStream.startCapture()

        state = .recording
        await MainActor.run { [weak self] in self?.onStateChanged?(.recording) }
    }

    func startVirtualChromakeyRecording(
        width: Int,
        height: Int,
        audioDevice: AVCaptureDevice?,
        outputURL: URL,
        drawingView: DrawingView,
        useAlphaChannel: Bool = false
    ) async throws {
        guard state == .idle else { return }

        recordingStartDate = Date()
        sessionStarted = false
        pendingAudioBuffers = []
        isVirtualChromakey = true
        isAlphaChannel = useAlphaChannel
        chromakeyDrawingView = drawingView
        chromakeyFrameCount = 0

        let encodeWidth = (width / 2) * 2
        let encodeHeight = (height / 2) * 2

        let fileType: AVFileType = useAlphaChannel ? .mov : .mp4
        let writer = try makeWriter(outputURL, fileType)
        let creationItem = AVMutableMetadataItem()
        creationItem.identifier = .quickTimeMetadataCreationDate
        creationItem.value = ISO8601DateFormatter().string(from: recordingStartDate) as NSString
        writer.metadata = [creationItem]
        self.assetWriter = writer

        let videoInput: AVAssetWriterInput
        if useAlphaChannel {
            videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
                    AVVideoWidthKey: encodeWidth,
                    AVVideoHeightKey: encodeHeight,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 12_000_000
                    ] as [String: Any]
                ]
            )
        } else {
            videoInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: encodeWidth,
                    AVVideoHeightKey: encodeHeight,
                    AVVideoColorPropertiesKey: [
                        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                    ],
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 8_000_000,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                        AVVideoMaxKeyFrameIntervalKey: 60
                    ] as [String: Any]
                ]
            )
        }
        videoInput.expectsMediaDataInRealTime = true
        self.videoInput = videoInput

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: encodeWidth,
                kCVPixelBufferHeightKey as String: encodeHeight,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
            ]
        )
        self.videoAdaptor = adaptor

        if writer.canAdd(videoInput) { writer.add(videoInput) }

        if audioDevice != nil {
            let audioInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128_000
                ]
            )
            audioInput.expectsMediaDataInRealTime = true
            self.audioInput = audioInput
            if writer.canAdd(audioInput) { writer.add(audioInput) }
        }

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "RecordingManager", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "AVAssetWriter.startWriting() failed"])
        }

        // Create pixel buffer pool for buffer reuse
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: encodeWidth,
            kCVPixelBufferHeightKey as String: encodeHeight,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
        ] as CFDictionary, &pool)
        chromakeyPixelBufferPool = pool

        if let audioDevice = audioDevice {
            startAudioCapture(device: audioDevice)
        }

        // Start 30fps timer on writingQueue
        let timer = DispatchSource.makeTimerSource(queue: writingQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 30.0)
        timer.setEventHandler { [weak self] in self?.renderChromakeyFrame() }
        chromakeyTimer = timer
        timer.resume()

        state = .recording
        await MainActor.run { [weak self] in self?.onStateChanged?(.recording) }
    }

    func stopRecording() async {
        guard state == .recording else { return }
        state = .idle

        try? await stream?.stopCapture()
        stream = nil

        captureSession?.stopRunning()
        captureSession = nil

        chromakeyTimer?.cancel()
        chromakeyTimer = nil
        isVirtualChromakey = false
        isAlphaChannel = false
        chromakeyDrawingView = nil
        chromakeyPixelBufferPool = nil
        chromakeyFrameCount = 0

        await finishWriting()

        await MainActor.run { [weak self] in self?.onStateChanged?(.idle) }
    }

    // MARK: - Private

    private func renderChromakeyFrame() {
        guard state == .recording,
              let writer = assetWriter,
              writer.status == AVAssetWriter.Status.writing,
              let drawingView = chromakeyDrawingView,
              let pool = chromakeyPixelBufferPool else { return }

        chromakeyFrameCount += 1
        let pts = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)

        if !sessionStarted {
            sessionStarted = true
            writer.startSession(atSourceTime: pts)
            for buf in pendingAudioBuffers {
                let bufPts = CMSampleBufferGetPresentationTimeStamp(buf)
                if bufPts >= pts, let audioIn = audioInput, audioIn.isReadyForMoreMediaData {
                    audioIn.append(buf)
                }
            }
            pendingAudioBuffers = []
        }

        guard let adaptor = videoAdaptor, adaptor.assetWriterInput.isReadyForMoreMediaData else { return }

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
              let pb = pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(pb, [])

        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pb),
              let ctx = CGContext(
                data: baseAddress,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
              ) else {
            CVPixelBufferUnlockBaseAddress(pb, [])
            return
        }

        // Fill background: transparent for alpha channel mode, solid chromakey color otherwise
        if isAlphaChannel {
            ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        } else {
            ctx.setFillColor(GreenScreenPreferences.color.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }

        // Both CGBitmapContext and unflipped NSView use Quartz coords (origin bottom-left, y upward).
        // Only a scale is needed — no flip.
        let viewSize: CGSize = DispatchQueue.main.sync { drawingView.bounds.size }
        ctx.scaleBy(x: CGFloat(w) / viewSize.width, y: CGFloat(h) / viewSize.height)

        // Render strokes on main thread (allStrokes + NSBezierPath drawing)
        DispatchQueue.main.sync { drawingView.render(into: ctx) }

        CVPixelBufferUnlockBaseAddress(pb, [])

        if !adaptor.append(pb, withPresentationTime: pts) {
            print("RecordingManager: chromakey frame drop — writer status \(writer.status.rawValue)")
        }
    }

    private func startAudioCapture(device: AVCaptureDevice) {
        let session = AVCaptureSession()
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: writingQueue)
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(output) { session.addOutput(output) }
            session.startRunning()
            self.captureSession = session
        } catch {
            print("RecordingManager: audio capture error: \(error)")
        }
    }

    private func finishWriting() async {
        // Drain the writing queue first — ensures all in-flight SCStream callbacks
        // have completed before we mark inputs as finished.
        await withCheckedContinuation { (drain: CheckedContinuation<Void, Never>) in
            writingQueue.async { drain.resume() }
        }

        guard let writer = assetWriter else { return }

        // No frames arrived — cancel (deletes the empty file)
        guard sessionStarted else {
            writer.cancelWriting()
            assetWriter = nil
            videoInput = nil
            audioInput = nil
            videoAdaptor = nil
            return
        }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        // finishWriting is async; bridge to structured concurrency
        await withCheckedContinuation { (finish: CheckedContinuation<Void, Never>) in
            writer.finishWriting(completionHandler: { finish.resume() })
        }
        if writer.status == AVAssetWriter.Status.failed {
            print("RecordingManager: finishWriting failed — \(writer.error?.localizedDescription ?? "unknown error")")
        } else {
            print("RecordingManager: file written successfully")
        }

        assetWriter = nil
        videoInput = nil
        audioInput = nil
        videoAdaptor = nil
    }
}

// MARK: - SCStreamOutput

extension RecordingManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              state == .recording,
              CMSampleBufferDataIsReady(sampleBuffer),
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let writer = assetWriter,
              writer.status == AVAssetWriter.Status.writing else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard pts.isValid else { return }

        if !sessionStarted {
            sessionStarted = true
            writer.startSession(atSourceTime: pts)
            // Flush any audio that arrived before the first video frame
            for buf in pendingAudioBuffers {
                let bufPts = CMSampleBufferGetPresentationTimeStamp(buf)
                if bufPts >= pts, let audioIn = audioInput, audioIn.isReadyForMoreMediaData {
                    audioIn.append(buf)
                }
            }
            pendingAudioBuffers = []
        }

        if let adaptor = videoAdaptor, adaptor.assetWriterInput.isReadyForMoreMediaData {
            if !adaptor.append(imageBuffer, withPresentationTime: pts) {
                print("RecordingManager: frame drop — writer status \(writer.status.rawValue), error: \(writer.error?.localizedDescription ?? "none")")
            }
        }
    }
}

// MARK: - SCStreamDelegate

extension RecordingManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("RecordingManager: SCStream stopped with error: \(error)")
        Task { await stopRecording() }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension RecordingManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard state == .recording,
              let writer = assetWriter,
              writer.status == AVAssetWriter.Status.writing,
              let audioInput = audioInput else { return }

        if !sessionStarted {
            if pendingAudioBuffers.count < 200 { // ~2 s safety cap
                pendingAudioBuffers.append(sampleBuffer)
            }
            return
        }

        guard audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(sampleBuffer)
    }
}
