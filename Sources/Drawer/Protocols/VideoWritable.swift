import AVFoundation
import CoreMedia

protocol VideoWritable: AnyObject {
    var status: AVAssetWriter.Status { get }
    var error: Error? { get }
    var metadata: [AVMetadataItem] { get set }
    func startWriting() -> Bool
    func startSession(atSourceTime startTime: CMTime)
    func canAdd(_ input: AVAssetWriterInput) -> Bool
    func add(_ input: AVAssetWriterInput)
    func cancelWriting()
    func finishWriting(completionHandler handler: @escaping @Sendable () -> Void)
}

extension AVAssetWriter: VideoWritable {}
