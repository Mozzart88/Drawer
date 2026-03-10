import Foundation
@preconcurrency import AVFoundation
import ScreenCaptureKit
import CoreMedia

enum RecordingState {
    case idle
    case recording
}

class RecordingManager: NSObject {

    private(set) var state: RecordingState = .idle
    var onStateChanged: ((RecordingState) -> Void)?

    private let writingQueue = DispatchQueue(label: "com.drawer.recording", qos: .userInitiated)

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var videoAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?

    private var stream: SCStream?
    private var captureSession: AVCaptureSession?

    private var recordingStartDate: Date = Date()
    private var sessionStarted = false
    private var pendingAudioBuffers: [CMSampleBuffer] = []

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

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

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

        let scStream = SCStream(filter: filter, configuration: config, delegate: self)
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

    func stopRecording() async {
        guard state == .recording else { return }
        state = .idle

        try? await stream?.stopCapture()
        stream = nil

        captureSession?.stopRunning()
        captureSession = nil

        await finishWriting()

        await MainActor.run { [weak self] in self?.onStateChanged?(.idle) }
    }

    // MARK: - Private

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
            writer.finishWriting { finish.resume() }
        }
        if writer.status == .failed {
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
              writer.status == .writing else { return }

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
              writer.status == .writing,
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
