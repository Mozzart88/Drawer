import AppKit

/// Public entry point called by the executable wrapper.
public func runDrawerApp() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
