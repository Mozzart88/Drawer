import ScreenCaptureKit
import Foundation

protocol ScreenCaptureStreamable: AnyObject {
    func addStreamOutput(_ output: SCStreamOutput, type: SCStreamOutputType,
                         sampleHandlerQueue: DispatchQueue?) throws
    func startCapture() async throws
    func stopCapture() async throws
}

extension SCStream: ScreenCaptureStreamable {}
