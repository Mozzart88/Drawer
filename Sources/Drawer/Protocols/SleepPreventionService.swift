import IOKit
import IOKit.pwr_mgt

protocol SleepPreventionService {
    func preventSleep(name: String) -> (Bool, IOPMAssertionID)
    func releaseSleep(id: IOPMAssertionID)
}

struct IOKitSleepPreventionService: SleepPreventionService {
    func preventSleep(name: String) -> (Bool, IOPMAssertionID) {
        var assertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &assertionID
        )
        return (result == kIOReturnSuccess, assertionID)
    }

    func releaseSleep(id: IOPMAssertionID) {
        IOPMAssertionRelease(id)
    }
}
