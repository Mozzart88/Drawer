import ScreenCaptureKit
import Foundation
@testable import DrawerCore

final class MockScreenCaptureStream: ScreenCaptureStreamable {
    var startCaptureCalled = false
    var stopCaptureCalled = false
    var addOutputCalled = false
    var shouldThrowOnStart = false

    func addStreamOutput(_ output: SCStreamOutput, type: SCStreamOutputType,
                         sampleHandlerQueue: DispatchQueue?) throws {
        addOutputCalled = true
    }

    func startCapture() async throws {
        startCaptureCalled = true
        if shouldThrowOnStart {
            throw NSError(domain: "MockStream", code: 1, userInfo: nil)
        }
    }

    func stopCapture() async throws {
        stopCaptureCalled = true
    }
}
