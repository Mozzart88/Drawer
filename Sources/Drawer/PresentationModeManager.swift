import AppKit
import IOKit
import IOKit.pwr_mgt

class PresentationModeManager {

    private let sleepService: SleepPreventionService
    private var sleepAssertionID: IOPMAssertionID = 0
    private var sleepAssertionActive = false
    private var widgetsWereHidden: Int = 0

    init(sleepService: SleepPreventionService = IOKitSleepPreventionService()) {
        self.sleepService = sleepService
    }

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
        let (success, id) = sleepService.preventSleep(name: "Drawer screen recording")
        if success {
            sleepAssertionID = id
            sleepAssertionActive = true
        }
    }

    private func allowSleep() {
        guard sleepAssertionActive else { return }
        sleepService.releaseSleep(id: sleepAssertionID)
        sleepAssertionActive = false
    }

    // MARK: - Dock & menu bar

    private func hideDockAndMenuBar() {
        DispatchQueue.main.async {
            NSApp?.presentationOptions = [.autoHideDock, .autoHideMenuBar]
        }
    }

    private func restoreDockAndMenuBar() {
        DispatchQueue.main.async {
            NSApp?.presentationOptions = []
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
