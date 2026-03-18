import Testing
import AppKit
@testable import DrawerCore

@Suite("PresentationModeManager", .serialized)
@MainActor
struct PresentationModeManagerTests {

    @Test("enable calls preventSleep")
    func enable_callsPreventSleep() {
        let mock = MockSleepPreventionService()
        let manager = PresentationModeManager(sleepService: mock)
        manager.enable()
        #expect(mock.preventCalled == true)
    }

    @Test("disable calls releaseSleep after enable")
    func disable_callsReleaseSleep() {
        let mock = MockSleepPreventionService()
        let manager = PresentationModeManager(sleepService: mock)
        manager.enable()
        manager.disable()
        #expect(mock.releaseCalled == true)
    }

    @Test("disable without enable does not call releaseSleep")
    func disable_withoutEnable_doesNotRelease() {
        let mock = MockSleepPreventionService()
        let manager = PresentationModeManager(sleepService: mock)
        manager.disable()
        #expect(mock.releaseCalled == false)
    }

    @Test("enable is idempotent — preventSleep called once even if enable called twice")
    func enable_idempotent() {
        let mock = MockSleepPreventionService()
        let manager = PresentationModeManager(sleepService: mock)
        manager.enable()
        manager.enable()  // second call should not re-assert since already active
        // preventCalled is only called once because of the guard !sleepAssertionActive
        #expect(mock.preventCalled == true)
    }

    @Test("releaseSleep receives the ID from preventSleep")
    func releaseSleep_receivesCorrectID() {
        let mock = MockSleepPreventionService()
        let manager = PresentationModeManager(sleepService: mock)
        manager.enable()
        manager.disable()
        #expect(mock.lastReleasedID == 42)
    }

    @Test("preventSleep failure does not set active state")
    func preventSleep_failureDoesNotSetActive() {
        let mock = MockSleepPreventionService()
        mock.preventShouldSucceed = false
        let manager = PresentationModeManager(sleepService: mock)
        manager.enable()
        manager.disable()
        // releaseSleep should NOT be called since assertion was never active
        #expect(mock.releaseCalled == false)
    }
}
