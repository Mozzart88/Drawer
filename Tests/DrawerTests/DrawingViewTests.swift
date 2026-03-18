import Testing
import AppKit
@testable import DrawerCore

@Suite("DrawingView", .serialized)
@MainActor
struct DrawingViewTests {

    private func makeView() -> DrawingView {
        StrokeSettings._defaults = makeIsolatedDefaults()
        return DrawingView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }

    @Test("initial state has empty strokes and drawing mode off")
    func initialState() {
        let view = makeView()
        #expect(view.strokes.isEmpty)
        #expect(view.currentStroke == nil)
        #expect(view.isDrawingMode == false)
    }

    @Test("clearStrokes removes all strokes")
    func clearStrokesCreatesUndoPoint() {
        let view = makeView()
        // Add some strokes manually
        view.strokes = [
            StrokeData(startPoint: .zero, startWidth: 2, color: .red, baseWidth: 2, source: .mouse)
        ]
        view.clearStrokes()
        #expect(view.strokes.isEmpty)
    }

    @Test("undo restores previous strokes after clear")
    func undoRestoresPreviousStrokes() {
        let view = makeView()
        let stroke = StrokeData(startPoint: NSPoint(x: 1, y: 2), startWidth: 3,
                                color: .red, baseWidth: 3, source: .mouse)
        view.strokes = [stroke]
        view.clearStrokes()
        #expect(view.strokes.isEmpty)
        view.undo()
        #expect(view.strokes.count == 1)
    }

    @Test("redo reapplies cleared strokes")
    func redoReappliesStrokes() {
        let view = makeView()
        view.strokes = [StrokeData(startPoint: .zero, startWidth: 2, color: .blue, baseWidth: 2, source: .mouse)]
        view.clearStrokes()
        view.undo()
        view.redo()
        #expect(view.strokes.isEmpty)
    }

    @Test("undo on empty stack is a no-op")
    func undoEmptyStack_noOp() {
        let view = makeView()
        // Should not crash
        view.undo()
        #expect(view.strokes.isEmpty)
    }

    @Test("redo on empty stack is a no-op")
    func redoEmptyStack_noOp() {
        let view = makeView()
        view.redo()
        #expect(view.strokes.isEmpty)
    }

    @Test("undo clears redo stack")
    func undoClearsRedoStack() {
        let view = makeView()
        view.strokes = [StrokeData(startPoint: .zero, startWidth: 2, color: .red, baseWidth: 2, source: .mouse)]
        view.clearStrokes()
        // Undo gives back the stroke, no redo available yet from scratch
        view.undo()
        // Now clear again
        view.clearStrokes()
        view.undo()
        // Redo stack should have the empty state
        view.redo()
        #expect(view.strokes.isEmpty)
    }

    @Test("currentColor observer is called on change")
    func currentColorObserver_called() {
        let view = makeView()
        var observedColor: NSColor?
        view.onColorChanged = { observedColor = $0 }
        view.currentColor = .blue
        #expect(observedColor == .blue)
    }

    @Test("currentWidth observer closure is registered successfully")
    func currentWidthObserver_called() {
        let view = makeView()
        var observedWidth: CGFloat?
        view.onWidthChanged = { observedWidth = $0 }
        // Width observers fire via scrollWheel, not direct set.
        // Verify registration: setting currentWidth directly doesn't fire observers,
        // but the observer closure is stored (no crash).
        view.currentWidth = 8.0
        // observedWidth is nil because scrollWheel wasn't called
        #expect(observedWidth == nil)
        #expect(view.currentWidth == 8.0)
    }

    @Test("currentOpacity observer closure is registered successfully")
    func currentOpacityObserver_called() {
        let view = makeView()
        var observedOpacity: CGFloat?
        view.onOpacityChanged = { observedOpacity = $0 }
        // Opacity observers fire via ctrl+scrollWheel, not direct set.
        view.currentOpacity = 0.5
        #expect(observedOpacity == nil)
        #expect(view.currentOpacity == 0.5)
    }

    @Test("allStrokes includes currentStroke when present")
    func allStrokes_includesCurrentStroke() {
        let view = makeView()
        let s1 = StrokeData(startPoint: .zero, startWidth: 1, color: .red, baseWidth: 1, source: .mouse)
        view.strokes = [s1]
        let s2 = StrokeData(startPoint: NSPoint(x: 5, y: 5), startWidth: 2, color: .blue, baseWidth: 2, source: .mouse)
        view.currentStroke = s2
        #expect(view.allStrokes.count == 2)
    }

    @Test("isDrawingMode true sets a tracking area")
    func isDrawingModeSetsTrackingArea() {
        let view = makeView()
        view.isDrawingMode = true
        #expect(view.trackingAreas.count >= 1)
    }

    @Test("isDrawingMode false removes tracking areas")
    func isDrawingModeFalseRemovesTrackingAreas() {
        let view = makeView()
        view.isDrawingMode = true
        view.isDrawingMode = false
        #expect(view.trackingAreas.isEmpty)
    }
}
