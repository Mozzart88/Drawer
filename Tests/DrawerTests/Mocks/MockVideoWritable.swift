import AVFoundation
import CoreMedia
@testable import DrawerCore

final class MockVideoWritable: VideoWritable {
    var status: AVAssetWriter.Status = .unknown
    var error: Error? = nil
    var metadata: [AVMetadataItem] = []

    var startWritingCalled = false
    var startWritingResult = true
    var startSessionCalled = false
    var startSessionTime: CMTime?
    var addedInputs: [AVAssetWriterInput] = []
    var canAddResult = true
    var cancelWritingCalled = false
    var finishWritingCalled = false

    func startWriting() -> Bool {
        startWritingCalled = true
        status = startWritingResult ? .writing : .failed
        return startWritingResult
    }

    func startSession(atSourceTime startTime: CMTime) {
        startSessionCalled = true
        startSessionTime = startTime
    }

    func canAdd(_ input: AVAssetWriterInput) -> Bool {
        return canAddResult
    }

    func add(_ input: AVAssetWriterInput) {
        addedInputs.append(input)
    }

    func cancelWriting() {
        cancelWritingCalled = true
    }

    func finishWriting(completionHandler handler: @escaping @Sendable () -> Void) {
        finishWritingCalled = true
        status = .completed
        handler()
    }
}
