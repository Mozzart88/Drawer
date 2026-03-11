import AppKit
import IOKit
import IOKit.pwr_mgt

class PresentationModeManager {

    private var sleepAssertionID: IOPMAssertionID = 0
    private var sleepAssertionActive = false
    private var widgetsWereHidden: Int = 0

    func enable() {
        enableDND()
        preventSleep()
        hideDockAndMenuBar()
        hideDesktopWidgets()
    }

    func disable() {
        disableDND()
        allowSleep()
        restoreDockAndMenuBar()
        restoreDesktopWidgets()
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

    // MARK: - Desktop Widgets

    private func hideDesktopWidgets() {
        guard #available(macOS 14, *) else { return }
        let defaults = UserDefaults(suiteName: "com.apple.WindowManager")
        widgetsWereHidden = defaults?.integer(forKey: "StandardHideWidgets") ?? 0
        defaults?.set(1, forKey: "StandardHideWidgets")
        defaults?.synchronize()
    }

    private func restoreDesktopWidgets() {
        guard #available(macOS 14, *) else { return }
        let defaults = UserDefaults(suiteName: "com.apple.WindowManager")
        defaults?.set(widgetsWereHidden, forKey: "StandardHideWidgets")
        defaults?.synchronize()
    }
}
