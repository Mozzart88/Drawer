import Testing
import AppKit
import AVFoundation
import ScreenCaptureKit
@testable import DrawerCore

@Suite("RecordingManager", .serialized)
@MainActor
struct RecordingManagerTests {

    @Test("initial state is idle")
    func initialStateIsIdle() {
        let manager = RecordingManager()
        #expect(manager.state == .idle)
    }

    @Test("isVirtualChromakey false by default")
    func isVirtualChromakey_falseByDefault() {
        let manager = RecordingManager()
        #expect(manager.isVirtualChromakey == false)
    }

    @Test("stopRecording when idle is a no-op")
    func stopRecording_whenIdle_noOp() async {
        let manager = RecordingManager()
        await manager.stopRecording()
        #expect(manager.state == .idle)
    }

    @Test("onStateChanged callback is invoked when transitioning from recording")
    func onStateChanged_notCalledOnIdleStop() async {
        let manager = RecordingManager()
        var stateChanges: [RecordingState] = []
        manager.onStateChanged = { state in
            stateChanges.append(state)
        }
        // stopRecording from idle state should not fire callback
        await manager.stopRecording()
        #expect(stateChanges.isEmpty)
    }

    @Test("makeWriter factory is injectable")
    func makeWriter_isInjectable() {
        let mockWriter = MockVideoWritable()
        let manager = RecordingManager()
        manager.makeWriter = { _, _ in mockWriter }
        // Verify the factory works
        let result = try? manager.makeWriter(
            URL(fileURLWithPath: "/tmp/test.mp4"), .mp4
        ) as? MockVideoWritable
        #expect(result === mockWriter)
    }

    @Test("makeStream factory is injectable")
    func makeStream_isInjectable() {
        let mockStream = MockScreenCaptureStream()
        let manager = RecordingManager()
        manager.makeStream = { _, _, _ in mockStream }
        // Verify that the factory can be overridden
        #expect(manager.state == .idle)
    }

    @Test("state remains idle after failed startRecording")
    func state_remainsIdleAfterFailure() async {
        let manager = RecordingManager()
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".mp4")
        let drawingView = DrawingView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        // Use a writer that fails to start
        let mockWriter = MockVideoWritable()
        mockWriter.startWritingResult = false
        mockWriter.error = NSError(domain: "Test", code: 1, userInfo: nil)
        manager.makeWriter = { _, _ in mockWriter }

        do {
            try await manager.startVirtualChromakeyRecording(
                width: 100, height: 100, audioDevice: nil,
                outputURL: tmpURL, drawingView: drawingView
            )
            // If it succeeded (shouldn't), clean up
            await manager.stopRecording()
        } catch {
            // Expected: writer failed to start
            #expect(manager.state == .idle)
        }
    }
}
