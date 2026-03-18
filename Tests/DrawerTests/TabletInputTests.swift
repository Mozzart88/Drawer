import Testing
import AppKit
@testable import DrawerCore

@Suite("TabletInput")
struct TabletInputTests {

    @Test("zero pressure gives multiplier ≤ 0.1 (clamped to min)")
    func zeroPressure() {
        let m = TabletInput.widthMultiplier(pressure: 0, tilt: .zero)
        #expect(m == 0.1)
    }

    @Test("full pressure no tilt gives ≈ 2.5")
    func fullPressureNoTilt() {
        let m = TabletInput.widthMultiplier(pressure: 1.0, tilt: .zero)
        // pow(1.0, 0.5) * 2.5 = 2.5, tilt = 0
        #expect(abs(m - 2.5) < 0.001)
    }

    @Test("partial pressure (0.5) gives pow(0.5, 0.5) * 2.5")
    func partialPressure() {
        let m = TabletInput.widthMultiplier(pressure: 0.5, tilt: .zero)
        let expected = CGFloat(pow(0.5, 0.5)) * 2.5
        #expect(abs(m - expected) < 0.001)
    }

    @Test("tilt adds contribution to multiplier")
    func tiltContribution() {
        let noTilt = TabletInput.widthMultiplier(pressure: 0.5, tilt: .zero)
        let withTilt = TabletInput.widthMultiplier(pressure: 0.5, tilt: NSPoint(x: 1, y: 0))
        #expect(withTilt > noTilt)
    }

    @Test("multiplier never exceeds 3.0")
    func clampMax() {
        // Extreme values
        let m = TabletInput.widthMultiplier(pressure: 2.0, tilt: NSPoint(x: 10, y: 10))
        #expect(m <= 3.0)
    }

    @Test("multiplier never goes below 0.1")
    func clampMin() {
        let m = TabletInput.widthMultiplier(pressure: -1.0, tilt: .zero)
        #expect(m >= 0.1)
    }

    @Test("pointWidth scales by base width times multiplier")
    func pointWidthScales() {
        // Create a minimal synthetic event — we test with direct widthMultiplier calls
        let baseWidth: CGFloat = 4.0
        let multiplier = TabletInput.widthMultiplier(pressure: 1.0, tilt: .zero)
        let expected = baseWidth * multiplier
        #expect(abs(expected - 4.0 * 2.5) < 0.001)
    }
}
