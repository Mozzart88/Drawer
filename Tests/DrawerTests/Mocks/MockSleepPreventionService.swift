import IOKit
@testable import DrawerCore

final class MockSleepPreventionService: SleepPreventionService {
    var preventCalled = false
    var releaseCalled = false
    var lastReleasedID: IOPMAssertionID = 0
    var preventShouldSucceed = true

    func preventSleep(name: String) -> (Bool, IOPMAssertionID) {
        preventCalled = true
        return (preventShouldSucceed, IOPMAssertionID(42))
    }

    func releaseSleep(id: IOPMAssertionID) {
        releaseCalled = true
        lastReleasedID = id
    }
}
