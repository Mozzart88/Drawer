import AppKit
import IOKit
import IOKit.pwr_mgt

class PresentationModeManager {

    private var sleepAssertionID: IOPMAssertionID = 0
    private var sleepAssertionActive = false

    func enable() {
        enableDND()
        preventSleep()
        hideDockAndMenuBar()
    }

    func disable() {
        disableDND()
        allowSleep()
        restoreDockAndMenuBar()
    }

    // MARK: - Do Not Disturb

    private func enableDND() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.apple.notificationcenterui.dndstart"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private func disableDND() {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.apple.notificationcenterui.dndend"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    // MARK: - Sleep prevention

    private func preventSleep() {
        guard !sleepAssertionActive else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Drawer screen recording" as CFString,
            &sleepAssertionID
        )
        if result == kIOReturnSuccess {
            sleepAssertionActive = true
        }
    }

    private func allowSleep() {
        guard sleepAssertionActive else { return }
        IOPMAssertionRelease(sleepAssertionID)
        sleepAssertionActive = false
    }

    // MARK: - Dock & menu bar

    private func hideDockAndMenuBar() {
        DispatchQueue.main.async {
            NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]
        }
    }

    private func restoreDockAndMenuBar() {
        DispatchQueue.main.async {
            NSApp.presentationOptions = []
        }
    }
}
