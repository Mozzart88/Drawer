import AppKit
import AVFoundation
import ScreenCaptureKit
import UniformTypeIdentifiers

class RecordingControlPanel: NSPanel, NSTextFieldDelegate {

    // Called when user clicks Record — passes filter, pixel dimensions, audio device, output URL, presentation mode flag, sourceRect, virtualChromakey flag, alphaChannel flag
    var onRecord: ((SCContentFilter, Int, Int, AVCaptureDevice?, URL, Bool, CGRect?, Bool, Bool) -> Void)?

    private var modeSegment: NSSegmentedControl!
    private var windowPicker: NSPopUpButton!
    private var audioSourcePicker: NSPopUpButton!
    private var outputPathField: NSTextField!
    private var presentationModeCheck: NSButton!
    private var virtualChromakeyCheck: NSButton!
    private var alphaChannelCheck: NSButton!
    private var alphaChannelRow: NSView!
    private var keyCastCheck: NSButton!
    private var keyCastLifetimeField: NSTextField!
    private var keyCastLifetimeRow: NSView!
    private var keyCastKeyFontField: NSTextField!
    private var keyCastKeyFontRow: NSView!
    private var keyCastBgColorWell: NSColorWell!
    private var keyCastBgColorRow: NSView!
    private var keyCastBgOpacityField: NSTextField!
    private var keyCastBgOpacitySlider: NSSlider!
    private var keyCastBgOpacityRow: NSView!
    private var keyCastDemoTextField: NSTextField!
    private var keyCastDemoTextRow: NSView!
    private var keyCastHintLabel: NSTextField!
    private var recordButton: NSButton!
    private var statusLabel: NSTextField!

    var teleprompterOverlay: TeleprompterOverlay?

    private var keyCastPreview: KeyCastOverlay?

    private var teleprompterCheck: NSButton!
    private var teleprompterFileRow: NSView!
    private var teleprompterFilePathField: NSTextField!
    private var teleprompterFontSizeRow: NSView!
    private var teleprompterFontSizeField: NSTextField!
    private var teleprompterFontColorRow: NSView!
    private var teleprompterFontColorWell: NSColorWell!
    private var teleprompterTextOpacityRow: NSView!
    private var teleprompterTextOpacityField: NSTextField!
    private var teleprompterTextOpacitySlider: NSSlider!
    private var teleprompterSizeRow: NSView!
    private var teleprompterWidthField: NSTextField!
    private var teleprompterHeightField: NSTextField!
    private var teleprompterBgColorRow: NSView!
    private var teleprompterBgColorWell: NSColorWell!
    private var teleprompterBgOpacityRow: NSView!
    private var teleprompterBgOpacityField: NSTextField!
    private var teleprompterBgOpacitySlider: NSSlider!
    private var teleprompterOverlayOpacityRow: NSView!
    private var teleprompterOverlayOpacityField: NSTextField!
    private var teleprompterOverlayOpacitySlider: NSSlider!
    private var teleprompterAutoScrollRow: NSView!
    private var teleprompterAutoScrollCheck: NSButton!
    private var teleprompterSpeedRow: NSView!
    private var teleprompterSpeedField: NSTextField!

    private var shareableContent: SCShareableContent?
    private var audioDevices: [AVCaptureDevice] = []
    private var outputURL: URL
    private var windowPickerOverlay: WindowPickerOverlay?

    init() {
        let dir = RecordingPreferences.saveDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        outputURL = dir.appendingPathComponent("Recording-\(formatter.string(from: Date())).mov")

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 1026),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "Screen Recording"
        isFloatingPanel = true
        level = .normal
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        setupUI()
        center()
        loadContent()
    }

    // MARK: - UI Setup

    private func setupUI() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 1026))
        contentView = content

        let lx: CGFloat = 10
        let lw: CGFloat = 90
        let cx: CGFloat = 108
        let cw: CGFloat = 282
        var y: CGFloat = 1018
        let rh: CGFloat = 26
        let rs: CGFloat = 38

        // Mode
        content.addSubview(makeLabel("Mode", frame: NSRect(x: lx, y: y + 3, width: lw, height: 20)))
        modeSegment = NSSegmentedControl(frame: NSRect(x: cx, y: y, width: cw, height: rh))
        modeSegment.segmentCount = 2
        modeSegment.setLabel("Full Screen", forSegment: 0)
        modeSegment.setLabel("Window", forSegment: 1)
        modeSegment.selectedSegment = 0
        modeSegment.target = self
        modeSegment.action = #selector(modeChanged)
        content.addSubview(modeSegment)
        y -= rs

        // Window picker
        content.addSubview(makeLabel("Window", frame: NSRect(x: lx, y: y + 3, width: lw, height: 20)))
        windowPicker = NSPopUpButton(frame: NSRect(x: cx, y: y, width: cw, height: rh))
        windowPicker.addItem(withTitle: "Loading…")
        windowPicker.isEnabled = false
        content.addSubview(windowPicker)
        y -= rs

        // Audio source
        content.addSubview(makeLabel("Audio", frame: NSRect(x: lx, y: y + 3, width: lw, height: 20)))
        audioSourcePicker = NSPopUpButton(frame: NSRect(x: cx, y: y, width: cw, height: rh))
        audioSourcePicker.addItem(withTitle: "None")
        content.addSubview(audioSourcePicker)
        y -= rs

        // Output path
        content.addSubview(makeLabel("Save to", frame: NSRect(x: lx, y: y + 3, width: lw, height: 20)))
        outputPathField = NSTextField(frame: NSRect(x: cx, y: y, width: cw - 70, height: rh))
        outputPathField.stringValue = outputURL.path
        outputPathField.isEditable = false
        outputPathField.usesSingleLineMode = true
        outputPathField.lineBreakMode = .byTruncatingMiddle
        content.addSubview(outputPathField)
        let browseBtn = NSButton(frame: NSRect(x: cx + cw - 65, y: y, width: 62, height: rh))
        browseBtn.title = "Browse…"
        browseBtn.bezelStyle = .rounded
        browseBtn.target = self
        browseBtn.action = #selector(browse)
        content.addSubview(browseBtn)
        y -= rs

        // Presentation mode
        presentationModeCheck = NSButton(frame: NSRect(x: cx, y: y + 2, width: cw, height: 22))
        presentationModeCheck.setButtonType(.switch)
        presentationModeCheck.title = "Presentation Mode (DND + prevent sleep)"
        content.addSubview(presentationModeCheck)
        y -= rs - 4

        // Virtual chromakey
        virtualChromakeyCheck = NSButton(frame: NSRect(x: cx, y: y + 2, width: cw, height: 22))
        virtualChromakeyCheck.setButtonType(.switch)
        virtualChromakeyCheck.title = "Virtual Chromakey (uses Green Screen color)"
        virtualChromakeyCheck.target = self
        virtualChromakeyCheck.action = #selector(virtualChromakeyToggled)
        content.addSubview(virtualChromakeyCheck)
        y -= rs - 4

        // Alpha channel (indented sub-option of virtual chromakey)
        let alphaRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        alphaChannelRow = alphaRow
        alphaChannelCheck = NSButton(frame: NSRect(x: 0, y: 0, width: cw - 16, height: 22))
        alphaChannelCheck.setButtonType(.switch)
        alphaChannelCheck.title = "Use Alpha Channel (HEVC with transparency)"
        alphaChannelCheck.target = self
        alphaChannelCheck.action = #selector(alphaChannelToggled)
        alphaRow.addSubview(alphaChannelCheck)
        content.addSubview(alphaRow)
        y -= rs - 4

        // Key casting toggle
        keyCastCheck = NSButton(frame: NSRect(x: cx, y: y + 2, width: cw, height: 22))
        keyCastCheck.setButtonType(.switch)
        keyCastCheck.title = "Show Key Casting"
        keyCastCheck.target = self
        keyCastCheck.action = #selector(keyCastToggled)
        content.addSubview(keyCastCheck)
        y -= rs - 4

        // Key visible for: [field] sec  (indented row)
        let lifetimeRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        keyCastLifetimeRow = lifetimeRow
        let lifetimeLbl = NSTextField(labelWithString: "Key visible for:")
        lifetimeLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        lifetimeLbl.font = NSFont.systemFont(ofSize: 13)
        lifetimeRow.addSubview(lifetimeLbl)
        keyCastLifetimeField = NSTextField(frame: NSRect(x: 106, y: 0, width: 50, height: 22))
        keyCastLifetimeField.stringValue = "1.5"
        keyCastLifetimeField.isEditable = true
        lifetimeRow.addSubview(keyCastLifetimeField)
        let secLbl = NSTextField(labelWithString: "sec")
        secLbl.frame = NSRect(x: 162, y: 1, width: 40, height: 20)
        secLbl.font = NSFont.systemFont(ofSize: 13)
        lifetimeRow.addSubview(secLbl)
        content.addSubview(lifetimeRow)
        y -= rs - 4

        // Key font size: [field] pt  (indented row)
        let keyFontRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        keyCastKeyFontRow = keyFontRow
        let keyFontLbl = NSTextField(labelWithString: "Key font size:")
        keyFontLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        keyFontLbl.font = NSFont.systemFont(ofSize: 13)
        keyFontRow.addSubview(keyFontLbl)
        keyCastKeyFontField = NSTextField(frame: NSRect(x: 106, y: 0, width: 50, height: 22))
        keyCastKeyFontField.stringValue = "20"
        keyCastKeyFontField.isEditable = true
        keyCastKeyFontField.delegate = self
        keyFontRow.addSubview(keyCastKeyFontField)
        let keyFontPtLbl = NSTextField(labelWithString: "pt")
        keyFontPtLbl.frame = NSRect(x: 162, y: 1, width: 30, height: 20)
        keyFontPtLbl.font = NSFont.systemFont(ofSize: 13)
        keyFontRow.addSubview(keyFontPtLbl)
        content.addSubview(keyFontRow)
        y -= rs - 4

        // BG color: [color well]  (indented row)
        let bgColorRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        keyCastBgColorRow = bgColorRow
        let bgColorLbl = NSTextField(labelWithString: "BG color:")
        bgColorLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        bgColorLbl.font = NSFont.systemFont(ofSize: 13)
        bgColorRow.addSubview(bgColorLbl)
        keyCastBgColorWell = ActivatingColorWell(frame: NSRect(x: 106, y: 0, width: 44, height: 22))
        keyCastBgColorWell.color = .black
        keyCastBgColorWell.target = self
        keyCastBgColorWell.action = #selector(bgColorChanged)
        bgColorRow.addSubview(keyCastBgColorWell)
        content.addSubview(bgColorRow)
        y -= rs - 4

        // BG opacity: [field] [slider]  (indented row)
        let bgOpacityRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        keyCastBgOpacityRow = bgOpacityRow
        let bgOpacityLbl = NSTextField(labelWithString: "BG opacity:")
        bgOpacityLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        bgOpacityLbl.font = NSFont.systemFont(ofSize: 13)
        bgOpacityRow.addSubview(bgOpacityLbl)
        keyCastBgOpacityField = NSTextField(frame: NSRect(x: 106, y: 0, width: 40, height: 22))
        keyCastBgOpacityField.stringValue = "0.75"
        keyCastBgOpacityField.isEditable = true
        keyCastBgOpacityField.delegate = self
        bgOpacityRow.addSubview(keyCastBgOpacityField)
        keyCastBgOpacitySlider = NSSlider(frame: NSRect(x: 152, y: 0, width: 90, height: 22))
        keyCastBgOpacitySlider.minValue = 0
        keyCastBgOpacitySlider.maxValue = 1
        keyCastBgOpacitySlider.doubleValue = 0.75
        keyCastBgOpacitySlider.isContinuous = true
        keyCastBgOpacitySlider.target = self
        keyCastBgOpacitySlider.action = #selector(bgOpacitySliderChanged)
        bgOpacityRow.addSubview(keyCastBgOpacitySlider)
        content.addSubview(bgOpacityRow)
        y -= rs - 4

        // Demo text: [field]  (indented row)
        let demoTextRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        keyCastDemoTextRow = demoTextRow
        let demoTextLbl = NSTextField(labelWithString: "Demo text:")
        demoTextLbl.frame = NSRect(x: 0, y: 1, width: 90, height: 20)
        demoTextLbl.font = NSFont.systemFont(ofSize: 13)
        demoTextRow.addSubview(demoTextLbl)
        keyCastDemoTextField = NSTextField(frame: NSRect(x: 106, y: 0, width: cw - 16 - 106, height: 22))
        keyCastDemoTextField.stringValue = "Hello ⎵ World"
        keyCastDemoTextField.isEditable = true
        keyCastDemoTextField.delegate = self
        demoTextRow.addSubview(keyCastDemoTextField)
        content.addSubview(demoTextRow)
        y -= rs - 4

        // Hint label
        keyCastHintLabel = NSTextField(labelWithString: "Drag the overlay to position it")
        keyCastHintLabel.frame = NSRect(x: cx + 16, y: y + 2, width: cw - 16, height: 20)
        keyCastHintLabel.font = NSFont.systemFont(ofSize: 11)
        keyCastHintLabel.textColor = .secondaryLabelColor
        content.addSubview(keyCastHintLabel)
        y -= rs - 4

        // ─── Teleprompter section ───
        let tpSep = NSBox(frame: NSRect(x: lx, y: y + 20, width: 380, height: 1))
        tpSep.boxType = .separator
        content.addSubview(tpSep)
        let tpHeader = NSTextField(labelWithString: "Teleprompter")
        tpHeader.frame = NSRect(x: lx, y: y + 2, width: 380, height: 20)
        tpHeader.alignment = .center
        tpHeader.font = NSFont.boldSystemFont(ofSize: 13)
        content.addSubview(tpHeader)
        y -= 30

        // Enable teleprompter
        teleprompterCheck = NSButton(frame: NSRect(x: cx, y: y + 2, width: cw, height: 22))
        teleprompterCheck.setButtonType(.switch)
        teleprompterCheck.title = "Enable Teleprompter"
        teleprompterCheck.target = self
        teleprompterCheck.action = #selector(teleprompterToggled)
        content.addSubview(teleprompterCheck)
        y -= rs - 4

        // Source file row
        let tpFileRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 26))
        teleprompterFileRow = tpFileRow
        let tpFileLbl = NSTextField(labelWithString: "File:")
        tpFileLbl.frame = NSRect(x: 0, y: 3, width: 30, height: 20)
        tpFileLbl.font = NSFont.systemFont(ofSize: 13)
        tpFileRow.addSubview(tpFileLbl)
        teleprompterFilePathField = NSTextField(frame: NSRect(x: 35, y: 0, width: cw - 16 - 35 - 68, height: 26))
        teleprompterFilePathField.isEditable = false
        teleprompterFilePathField.usesSingleLineMode = true
        teleprompterFilePathField.lineBreakMode = .byTruncatingMiddle
        teleprompterFilePathField.placeholderString = "No file selected"
        tpFileRow.addSubview(teleprompterFilePathField)
        let tpBrowseBtn = NSButton(frame: NSRect(x: cw - 16 - 65, y: 0, width: 62, height: 26))
        tpBrowseBtn.title = "Browse…"
        tpBrowseBtn.bezelStyle = .rounded
        tpBrowseBtn.target = self
        tpBrowseBtn.action = #selector(browseForTeleprompterFile)
        tpFileRow.addSubview(tpBrowseBtn)
        content.addSubview(tpFileRow)
        y -= rs - 4

        // Font size
        let tpFontSizeRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        teleprompterFontSizeRow = tpFontSizeRow
        let tpFontSizeLbl = NSTextField(labelWithString: "Font size:")
        tpFontSizeLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        tpFontSizeLbl.font = NSFont.systemFont(ofSize: 13)
        tpFontSizeRow.addSubview(tpFontSizeLbl)
        teleprompterFontSizeField = NSTextField(frame: NSRect(x: 106, y: 0, width: 50, height: 22))
        teleprompterFontSizeField.stringValue = "28"
        teleprompterFontSizeField.isEditable = true
        teleprompterFontSizeField.delegate = self
        tpFontSizeRow.addSubview(teleprompterFontSizeField)
        let tpFontPtLbl = NSTextField(labelWithString: "pt")
        tpFontPtLbl.frame = NSRect(x: 162, y: 1, width: 30, height: 20)
        tpFontPtLbl.font = NSFont.systemFont(ofSize: 13)
        tpFontSizeRow.addSubview(tpFontPtLbl)
        content.addSubview(tpFontSizeRow)
        y -= rs - 4

        // Font color
        let tpFontColorRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        teleprompterFontColorRow = tpFontColorRow
        let tpFontColorLbl = NSTextField(labelWithString: "Font color:")
        tpFontColorLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        tpFontColorLbl.font = NSFont.systemFont(ofSize: 13)
        tpFontColorRow.addSubview(tpFontColorLbl)
        teleprompterFontColorWell = ActivatingColorWell(frame: NSRect(x: 106, y: 0, width: 44, height: 22))
        teleprompterFontColorWell.color = .white
        teleprompterFontColorWell.target = self
        teleprompterFontColorWell.action = #selector(teleprompterFontColorChanged)
        tpFontColorRow.addSubview(teleprompterFontColorWell)
        content.addSubview(tpFontColorRow)
        y -= rs - 4

        // Text opacity
        let tpOpacityRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        teleprompterTextOpacityRow = tpOpacityRow
        let tpOpacityLbl = NSTextField(labelWithString: "Text opacity:")
        tpOpacityLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        tpOpacityLbl.font = NSFont.systemFont(ofSize: 13)
        tpOpacityRow.addSubview(tpOpacityLbl)
        teleprompterTextOpacityField = NSTextField(frame: NSRect(x: 106, y: 0, width: 40, height: 22))
        teleprompterTextOpacityField.stringValue = "1.00"
        teleprompterTextOpacityField.isEditable = true
        teleprompterTextOpacityField.delegate = self
        tpOpacityRow.addSubview(teleprompterTextOpacityField)
        teleprompterTextOpacitySlider = NSSlider(frame: NSRect(x: 152, y: 0, width: 90, height: 22))
        teleprompterTextOpacitySlider.minValue = 0
        teleprompterTextOpacitySlider.maxValue = 1
        teleprompterTextOpacitySlider.doubleValue = 1.0
        teleprompterTextOpacitySlider.isContinuous = true
        teleprompterTextOpacitySlider.target = self
        teleprompterTextOpacitySlider.action = #selector(teleprompterTextOpacitySliderChanged)
        tpOpacityRow.addSubview(teleprompterTextOpacitySlider)
        content.addSubview(tpOpacityRow)
        y -= rs - 4

        // Overlay size (W × H)
        let tpSizeRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        teleprompterSizeRow = tpSizeRow
        let tpSizeLbl = NSTextField(labelWithString: "Size (W × H):")
        tpSizeLbl.frame = NSRect(x: 0, y: 1, width: 110, height: 20)
        tpSizeLbl.font = NSFont.systemFont(ofSize: 13)
        tpSizeRow.addSubview(tpSizeLbl)
        teleprompterWidthField = NSTextField(frame: NSRect(x: 116, y: 0, width: 50, height: 22))
        teleprompterWidthField.stringValue = "400"
        teleprompterWidthField.isEditable = true
        teleprompterWidthField.delegate = self
        tpSizeRow.addSubview(teleprompterWidthField)
        let tpSizeXLbl = NSTextField(labelWithString: "×")
        tpSizeXLbl.frame = NSRect(x: 172, y: 1, width: 14, height: 20)
        tpSizeXLbl.font = NSFont.systemFont(ofSize: 13)
        tpSizeRow.addSubview(tpSizeXLbl)
        teleprompterHeightField = NSTextField(frame: NSRect(x: 192, y: 0, width: 50, height: 22))
        teleprompterHeightField.stringValue = "300"
        teleprompterHeightField.isEditable = true
        teleprompterHeightField.delegate = self
        tpSizeRow.addSubview(teleprompterHeightField)
        content.addSubview(tpSizeRow)
        y -= rs - 4

        // Background color
        let tpBgColorRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        teleprompterBgColorRow = tpBgColorRow
        let tpBgColorLbl = NSTextField(labelWithString: "BG color:")
        tpBgColorLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        tpBgColorLbl.font = NSFont.systemFont(ofSize: 13)
        tpBgColorRow.addSubview(tpBgColorLbl)
        teleprompterBgColorWell = ActivatingColorWell(frame: NSRect(x: 106, y: 0, width: 44, height: 22))
        teleprompterBgColorWell.color = .black
        teleprompterBgColorWell.target = self
        teleprompterBgColorWell.action = #selector(teleprompterBgColorChanged)
        tpBgColorRow.addSubview(teleprompterBgColorWell)
        content.addSubview(tpBgColorRow)
        y -= rs - 4

        // Background opacity
        let tpBgOpacityRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        teleprompterBgOpacityRow = tpBgOpacityRow
        let tpBgOpacityLbl = NSTextField(labelWithString: "BG opacity:")
        tpBgOpacityLbl.frame = NSRect(x: 0, y: 1, width: 100, height: 20)
        tpBgOpacityLbl.font = NSFont.systemFont(ofSize: 13)
        tpBgOpacityRow.addSubview(tpBgOpacityLbl)
        teleprompterBgOpacityField = NSTextField(frame: NSRect(x: 106, y: 0, width: 40, height: 22))
        teleprompterBgOpacityField.stringValue = "0.70"
        teleprompterBgOpacityField.isEditable = true
        teleprompterBgOpacityField.delegate = self
        tpBgOpacityRow.addSubview(teleprompterBgOpacityField)
        teleprompterBgOpacitySlider = NSSlider(frame: NSRect(x: 152, y: 0, width: 90, height: 22))
        teleprompterBgOpacitySlider.minValue = 0
        teleprompterBgOpacitySlider.maxValue = 1
        teleprompterBgOpacitySlider.doubleValue = 0.7
        teleprompterBgOpacitySlider.isContinuous = true
        teleprompterBgOpacitySlider.target = self
        teleprompterBgOpacitySlider.action = #selector(teleprompterBgOpacitySliderChanged)
        tpBgOpacityRow.addSubview(teleprompterBgOpacitySlider)
        content.addSubview(tpBgOpacityRow)
        y -= rs - 4

        // Overlay opacity
        let tpOverlayOpacityRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        teleprompterOverlayOpacityRow = tpOverlayOpacityRow
        let tpOverlayOpacityLbl = NSTextField(labelWithString: "Overlay opacity:")
        tpOverlayOpacityLbl.frame = NSRect(x: 0, y: 1, width: 110, height: 20)
        tpOverlayOpacityLbl.font = NSFont.systemFont(ofSize: 13)
        tpOverlayOpacityRow.addSubview(tpOverlayOpacityLbl)
        teleprompterOverlayOpacityField = NSTextField(frame: NSRect(x: 116, y: 0, width: 40, height: 22))
        teleprompterOverlayOpacityField.stringValue = "1.00"
        teleprompterOverlayOpacityField.isEditable = true
        teleprompterOverlayOpacityField.delegate = self
        tpOverlayOpacityRow.addSubview(teleprompterOverlayOpacityField)
        teleprompterOverlayOpacitySlider = NSSlider(frame: NSRect(x: 162, y: 0, width: 80, height: 22))
        teleprompterOverlayOpacitySlider.minValue = 0
        teleprompterOverlayOpacitySlider.maxValue = 1
        teleprompterOverlayOpacitySlider.doubleValue = 1.0
        teleprompterOverlayOpacitySlider.isContinuous = true
        teleprompterOverlayOpacitySlider.target = self
        teleprompterOverlayOpacitySlider.action = #selector(teleprompterOverlayOpacitySliderChanged)
        tpOverlayOpacityRow.addSubview(teleprompterOverlayOpacitySlider)
        content.addSubview(tpOverlayOpacityRow)
        y -= rs - 4

        // Auto-scroll toggle
        let tpAutoScrollRow = NSView(frame: NSRect(x: cx + 16, y: y, width: cw - 16, height: 22))
        teleprompterAutoScrollRow = tpAutoScrollRow
        teleprompterAutoScrollCheck = NSButton(frame: NSRect(x: 0, y: 0, width: cw - 16, height: 22))
        teleprompterAutoScrollCheck.setButtonType(.switch)
        teleprompterAutoScrollCheck.title = "Auto-Scroll"
        teleprompterAutoScrollCheck.target = self
        teleprompterAutoScrollCheck.action = #selector(teleprompterAutoScrollToggled)
        tpAutoScrollRow.addSubview(teleprompterAutoScrollCheck)
        content.addSubview(tpAutoScrollRow)
        y -= rs - 4

        // Auto-scroll speed (sub-row)
        let tpSpeedRow = NSView(frame: NSRect(x: cx + 32, y: y, width: cw - 32, height: 22))
        teleprompterSpeedRow = tpSpeedRow
        let tpSpeedLbl = NSTextField(labelWithString: "Speed:")
        tpSpeedLbl.frame = NSRect(x: 0, y: 1, width: 60, height: 20)
        tpSpeedLbl.font = NSFont.systemFont(ofSize: 13)
        tpSpeedRow.addSubview(tpSpeedLbl)
        teleprompterSpeedField = NSTextField(frame: NSRect(x: 66, y: 0, width: 50, height: 22))
        teleprompterSpeedField.stringValue = "2.5"
        teleprompterSpeedField.isEditable = true
        teleprompterSpeedField.delegate = self
        tpSpeedRow.addSubview(teleprompterSpeedField)
        let tpSpeedUnitLbl = NSTextField(labelWithString: "wps")
        tpSpeedUnitLbl.frame = NSRect(x: 122, y: 1, width: 30, height: 20)
        tpSpeedUnitLbl.font = NSFont.systemFont(ofSize: 13)
        tpSpeedRow.addSubview(tpSpeedUnitLbl)
        content.addSubview(tpSpeedRow)
        y -= rs - 4

        // Status label
        statusLabel = NSTextField(frame: NSRect(x: lx, y: y, width: 380, height: 18))
        statusLabel.isEditable = false
        statusLabel.isBezeled = false
        statusLabel.drawsBackground = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.stringValue = "Requesting screen recording permission…"
        content.addSubview(statusLabel)

        // Buttons
        let cancelBtn = NSButton(frame: NSRect(x: lx, y: 14, width: 80, height: 32))
        cancelBtn.title = "Cancel"
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1B}"
        cancelBtn.target = self
        cancelBtn.action = #selector(cancel)
        content.addSubview(cancelBtn)

        recordButton = NSButton(frame: NSRect(x: 300, y: 14, width: 90, height: 32))
        recordButton.title = "Record"
        recordButton.bezelStyle = .rounded
        recordButton.keyEquivalent = "\r"
        recordButton.isEnabled = false
        recordButton.target = self
        recordButton.action = #selector(startRecording)
        content.addSubview(recordButton)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }

        // Key casting fields
        if let overlay = keyCastPreview {
            if field === keyCastKeyFontField, let v = Double(field.stringValue), v > 0 {
                overlay.keyFontSize = CGFloat(v)
            } else if field === keyCastBgOpacityField, let v = Double(field.stringValue), (0...1).contains(v) {
                keyCastBgOpacitySlider.doubleValue = v
                overlay.overlayBackgroundOpacity = CGFloat(v)
            } else if field === keyCastDemoTextField {
                overlay.demoText = field.stringValue.isEmpty ? "Hello ⎵ World" : field.stringValue
                overlay.showDemoText()
            }
        }

        // Teleprompter fields
        if field === teleprompterFontSizeField, let v = Double(field.stringValue), v > 0 {
            TeleprompterPreferences.fontSize = v
            teleprompterOverlay?.applyPreferences()
        } else if field === teleprompterTextOpacityField, let v = Double(field.stringValue), (0...1).contains(v) {
            teleprompterTextOpacitySlider.doubleValue = v
            TeleprompterPreferences.textOpacity = v
            teleprompterOverlay?.applyPreferences()
        } else if field === teleprompterBgOpacityField, let v = Double(field.stringValue), (0...1).contains(v) {
            teleprompterBgOpacitySlider.doubleValue = v
            TeleprompterPreferences.backgroundOpacity = v
            teleprompterOverlay?.applyPreferences()
        } else if field === teleprompterOverlayOpacityField, let v = Double(field.stringValue), (0...1).contains(v) {
            teleprompterOverlayOpacitySlider.doubleValue = v
            TeleprompterPreferences.overlayOpacity = v
            teleprompterOverlay?.applyPreferences()
        } else if field === teleprompterWidthField, let w = Double(field.stringValue), w > 0 {
            var f = TeleprompterPreferences.overlayFrame
            f.size.width = CGFloat(w)
            TeleprompterPreferences.overlayFrame = f
            teleprompterOverlay?.applyPreferences()
        } else if field === teleprompterHeightField, let h = Double(field.stringValue), h > 0 {
            var f = TeleprompterPreferences.overlayFrame
            f.size.height = CGFloat(h)
            TeleprompterPreferences.overlayFrame = f
            teleprompterOverlay?.applyPreferences()
        } else if field === teleprompterSpeedField, let v = Double(field.stringValue), v > 0 {
            TeleprompterPreferences.autoScrollSpeed = v
        }
    }

    private func makeLabel(_ text: String, frame: NSRect) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.frame = frame
        tf.alignment = .right
        return tf
    }

    // MARK: - Content loading

    private func loadContent() {
        // Audio devices (synchronous)
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone]
        } else {
            deviceTypes = [.builtInMicrophone]
        }
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )
        audioDevices = discoverySession.devices
        audioSourcePicker.removeAllItems()
        audioSourcePicker.addItem(withTitle: "None")
        for device in audioDevices {
            audioSourcePicker.addItem(withTitle: device.localizedName)
        }

        // Restore saved audio device selection
        if let savedUID = RecordingPreferences.audioDeviceUID,
           let idx = audioDevices.firstIndex(where: { $0.uniqueID == savedUID }) {
            audioSourcePicker.selectItem(at: idx + 1) // +1 for leading "None" item
        }

        // Restore presentation mode checkbox
        presentationModeCheck.state = RecordingPreferences.presentationMode ? .on : .off

        // Restore virtual chromakey checkbox
        virtualChromakeyCheck.state = RecordingPreferences.virtualChromakeyEnabled ? .on : .off

        // Restore alpha channel checkbox and visibility
        let alphaOn = RecordingPreferences.alphaChannelEnabled && RecordingPreferences.virtualChromakeyEnabled
        alphaChannelCheck.state = alphaOn ? .on : .off
        alphaChannelRow.isHidden = !RecordingPreferences.virtualChromakeyEnabled
        updateOutputURLExtension()

        // Restore key casting preferences
        let keyCastOn = RecordingPreferences.keyCastingEnabled
        keyCastCheck.state = keyCastOn ? .on : .off
        keyCastLifetimeField.stringValue = "\(RecordingPreferences.keyCastingLifetime)"
        keyCastKeyFontField.stringValue = "\(Int(RecordingPreferences.keyCastingKeyFontSize))"
        keyCastBgColorWell.color = RecordingPreferences.keyCastingBgColor
        keyCastBgOpacityField.stringValue = "\(RecordingPreferences.keyCastingBgOpacity)"
        keyCastBgOpacitySlider.doubleValue = Double(RecordingPreferences.keyCastingBgOpacity)
        keyCastDemoTextField.stringValue = RecordingPreferences.keyCastingDemoText
        keyCastLifetimeRow.isHidden = !keyCastOn
        keyCastKeyFontRow.isHidden = !keyCastOn
        keyCastBgColorRow.isHidden = !keyCastOn
        keyCastBgOpacityRow.isHidden = !keyCastOn
        keyCastDemoTextRow.isHidden = !keyCastOn
        keyCastHintLabel.isHidden = !keyCastOn
        if keyCastOn { showKeyCastPreview() }

        // Restore teleprompter preferences
        let tpOn = TeleprompterPreferences.enabled
        teleprompterCheck.state = tpOn ? .on : .off
        if let path = TeleprompterPreferences.filePath {
            teleprompterFilePathField.stringValue = path
        }
        teleprompterFontSizeField.stringValue = "\(Int(TeleprompterPreferences.fontSize))"
        teleprompterFontColorWell.color = TeleprompterPreferences.fontColor
        teleprompterTextOpacityField.stringValue = String(format: "%.2f", TeleprompterPreferences.textOpacity)
        teleprompterTextOpacitySlider.doubleValue = TeleprompterPreferences.textOpacity
        let overlayFrame = TeleprompterPreferences.overlayFrame
        teleprompterWidthField.stringValue = "\(Int(overlayFrame.width))"
        teleprompterHeightField.stringValue = "\(Int(overlayFrame.height))"
        teleprompterBgColorWell.color = NSColor(teleprompterHex: TeleprompterPreferences.backgroundColorHex) ?? .black
        teleprompterBgOpacityField.stringValue = String(format: "%.2f", TeleprompterPreferences.backgroundOpacity)
        teleprompterBgOpacitySlider.doubleValue = TeleprompterPreferences.backgroundOpacity
        teleprompterOverlayOpacityField.stringValue = String(format: "%.2f", TeleprompterPreferences.overlayOpacity)
        teleprompterOverlayOpacitySlider.doubleValue = TeleprompterPreferences.overlayOpacity
        teleprompterAutoScrollCheck.state = TeleprompterPreferences.autoScroll ? .on : .off
        teleprompterSpeedField.stringValue = String(format: "%.1f", TeleprompterPreferences.autoScrollSpeed)
        updateTeleprompterSubcontrols()

        // Shareable content (async — requires screen recording permission)
        Task {
            do {
                let content = try await SCShareableContent.current
                await MainActor.run {
                    self.shareableContent = content
                    self.populateWindowPicker(windows: content.windows)
                    self.recordButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "Screen recording permission required in System Settings."
                    self.statusLabel.textColor = .systemRed
                }
            }
        }
    }

    private func populateWindowPicker(windows: [SCWindow]) {
        // Keep only normal on-screen windows belonging to a real app
        let visible = windows.filter {
            $0.isOnScreen &&
            $0.windowLayer == 0 &&
            $0.owningApplication != nil &&
            $0.frame.width > 50 &&
            $0.frame.height > 50
        }

        let appWindows = visible.sorted {
            let a0 = $0.owningApplication!.applicationName
            let a1 = $1.owningApplication!.applicationName
            let cmp = a0.localizedCaseInsensitiveCompare(a1)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            let t0 = $0.title ?? ""
            let t1 = $1.title ?? ""
            return t0.localizedCaseInsensitiveCompare(t1) == .orderedAscending
        }

        windowPicker.removeAllItems()
        windowPicker.addItem(withTitle: "Click to pick…")
        for window in appWindows {
            let appName = window.owningApplication!.applicationName
            let winTitle = window.title.flatMap { $0.isEmpty ? nil : $0 } ?? appName
            let label = winTitle == appName ? appName : "\(appName) — \(winTitle)"
            windowPicker.addItem(withTitle: label)
            windowPicker.lastItem?.representedObject = window
        }
        windowPicker.isEnabled = modeSegment.selectedSegment == 1
        statusLabel.stringValue = "Ready. \(appWindows.count) windows available."
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        windowPicker.isEnabled = modeSegment.selectedSegment == 1
    }

    @objc private func browse() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = URL(fileURLWithPath: outputPathField.stringValue).lastPathComponent
        panel.beginSheetModal(for: self) { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            self.outputURL = url
            self.outputPathField.stringValue = url.path
            RecordingPreferences.saveDirectory = url.deletingLastPathComponent()
        }
    }

    @objc private func cancel() {
        hideKeyCastPreview()
        orderOut(nil)
    }

    @objc private func virtualChromakeyToggled() {
        let on = virtualChromakeyCheck.state == .on
        alphaChannelRow.isHidden = !on
        if !on { alphaChannelCheck.state = .off }
        updateOutputURLExtension()
    }

    @objc private func alphaChannelToggled() {
        updateOutputURLExtension()
    }

    private func updateOutputURLExtension() {
        let ext = "mov"
        outputURL = outputURL.deletingPathExtension().appendingPathExtension(ext)
        outputPathField.stringValue = outputURL.path
    }

    @objc private func keyCastToggled() {
        let on = keyCastCheck.state == .on
        keyCastLifetimeRow.isHidden = !on
        keyCastKeyFontRow.isHidden = !on
        keyCastBgColorRow.isHidden = !on
        keyCastBgOpacityRow.isHidden = !on
        keyCastDemoTextRow.isHidden = !on
        keyCastHintLabel.isHidden = !on
        if on {
            showKeyCastPreview()
        } else {
            hideKeyCastPreview()
        }
    }

    @objc private func bgColorChanged() {
        keyCastPreview?.overlayBackgroundColor = keyCastBgColorWell.color
    }

    @objc private func bgOpacitySliderChanged() {
        let v = keyCastBgOpacitySlider.doubleValue
        keyCastBgOpacityField.stringValue = String(format: "%.2f", v)
        keyCastPreview?.overlayBackgroundOpacity = CGFloat(v)
    }

    // MARK: - Teleprompter Actions

    @objc private func teleprompterToggled() {
        let on = teleprompterCheck.state == .on
        TeleprompterPreferences.enabled = on
        updateTeleprompterSubcontrols()
        if on, let path = TeleprompterPreferences.filePath {
            teleprompterOverlay?.loadFile(path)
            teleprompterOverlay?.makeKeyAndOrderFront(nil)
        } else if !on {
            teleprompterOverlay?.orderOut(nil)
        }
    }

    @objc private func browseForTeleprompterFile() {
        let panel = NSOpenPanel()
        let mdType = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = [.plainText, mdType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: self) { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            let path = url.path
            TeleprompterPreferences.filePath = path
            self.teleprompterFilePathField.stringValue = path
            self.teleprompterOverlay?.loadFile(path)
            if TeleprompterPreferences.enabled {
                self.teleprompterOverlay?.makeKeyAndOrderFront(nil)
            }
        }
    }

    @objc private func teleprompterFontColorChanged() {
        TeleprompterPreferences.fontColor = teleprompterFontColorWell.color
        teleprompterOverlay?.applyPreferences()
    }

    @objc private func teleprompterTextOpacitySliderChanged() {
        let v = teleprompterTextOpacitySlider.doubleValue
        teleprompterTextOpacityField.stringValue = String(format: "%.2f", v)
        TeleprompterPreferences.textOpacity = v
        teleprompterOverlay?.applyPreferences()
    }

    @objc private func teleprompterBgColorChanged() {
        TeleprompterPreferences.backgroundColorHex = teleprompterBgColorWell.color.teleprompterHexString
        teleprompterOverlay?.applyPreferences()
    }

    @objc private func teleprompterBgOpacitySliderChanged() {
        let v = teleprompterBgOpacitySlider.doubleValue
        teleprompterBgOpacityField.stringValue = String(format: "%.2f", v)
        TeleprompterPreferences.backgroundOpacity = v
        teleprompterOverlay?.applyPreferences()
    }

    @objc private func teleprompterOverlayOpacitySliderChanged() {
        let v = teleprompterOverlayOpacitySlider.doubleValue
        teleprompterOverlayOpacityField.stringValue = String(format: "%.2f", v)
        TeleprompterPreferences.overlayOpacity = v
        teleprompterOverlay?.applyPreferences()
    }

    @objc private func teleprompterAutoScrollToggled() {
        updateTeleprompterSubcontrols()
        let autoScrollOn = teleprompterAutoScrollCheck.state == .on
        TeleprompterPreferences.autoScroll = autoScrollOn
        if autoScrollOn {
            teleprompterOverlay?.startAutoScroll()
        } else {
            teleprompterOverlay?.stopAutoScroll()
        }
    }

    private func updateTeleprompterSubcontrols() {
        let on = teleprompterCheck.state == .on
        teleprompterFileRow.isHidden = !on
        teleprompterFontSizeRow.isHidden = !on
        teleprompterFontColorRow.isHidden = !on
        teleprompterTextOpacityRow.isHidden = !on
        teleprompterSizeRow.isHidden = !on
        teleprompterBgColorRow.isHidden = !on
        teleprompterBgOpacityRow.isHidden = !on
        teleprompterOverlayOpacityRow.isHidden = !on
        teleprompterAutoScrollRow.isHidden = !on
        let autoScrollOn = on && teleprompterAutoScrollCheck.state == .on
        teleprompterSpeedRow.isHidden = !autoScrollOn
    }

    private func showKeyCastPreview() {
        hideKeyCastPreview()
        let overlay = KeyCastOverlay()
        if let lifetime = Double(keyCastLifetimeField.stringValue), lifetime > 0 {
            overlay.keyLifetime = lifetime
        } else {
            overlay.keyLifetime = RecordingPreferences.keyCastingLifetime
        }
        if let size = Double(keyCastKeyFontField.stringValue), size > 0 {
            overlay.keyFontSize = CGFloat(size)
        }
        overlay.overlayBackgroundColor = keyCastBgColorWell.color
        overlay.overlayBackgroundOpacity = CGFloat(Double(keyCastBgOpacityField.stringValue) ?? 0.75)
        overlay.demoText = keyCastDemoTextField.stringValue.isEmpty
            ? "Hello ⎵ World"
            : keyCastDemoTextField.stringValue
        overlay.moveToSavedPosition()
        overlay.orderFront(nil)
        overlay.showDemoText()
        keyCastPreview = overlay
    }

    private func hideKeyCastPreview() {
        keyCastPreview?.orderOut(nil)
        keyCastPreview = nil
    }

    @objc private func startRecording() {
        guard let content = shareableContent else { return }

        let isPresentationMode = presentationModeCheck.state == .on
        let audioIndex = audioSourcePicker.indexOfSelectedItem - 1 // 0 = "None"
        let audioDevice: AVCaptureDevice? = audioIndex >= 0 && audioIndex < audioDevices.count
            ? audioDevices[audioIndex] : nil

        // Window mode + click-to-pick
        if modeSegment.selectedSegment == 1 && windowPicker.indexOfSelectedItem == 0 {
            let isVirtualChromakey = virtualChromakeyCheck.state == .on
            let isAlphaChannel = alphaChannelCheck.state == .on
            RecordingPreferences.virtualChromakeyEnabled = isVirtualChromakey
            RecordingPreferences.alphaChannelEnabled = isAlphaChannel
            orderOut(nil)
            showWindowPicker(
                windows: content.windows,
                audioDevice: audioDevice,
                presentationMode: isPresentationMode,
                virtualChromakey: isVirtualChromakey,
                alphaChannel: isAlphaChannel
            )
            return
        }

        let filter: SCContentFilter
        let width: Int
        let height: Int

        let sourceRect: CGRect?

        if modeSegment.selectedSegment == 0 {
            // Full screen — use NSScreen physical pixels (SCDisplay.width is in logical points)
            guard let display = content.displays.first else { return }
            // Full display capture — TeleprompterOverlay and StrokeHUDPanel are excluded via
            // sharingType = .none. KeyCastOverlay (sharingType = .readOnly) appears in the video.
            // The old excludingApplications approach blacklisted KeyCastOverlay because NSPanel
            // at .screenSaver level is never enumerated in SCShareableContent.windows.
            filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let scale = screen.backingScaleFactor
            width = (Int(screen.frame.width * scale) / 2) * 2
            height = (Int(screen.frame.height * scale) / 2) * 2
            sourceRect = nil
        } else {
            // Selected window — scWindow.frame is in points, convert to pixels
            guard let scWindow = selectedSCWindow() else {
                statusLabel.stringValue = "Please select a window."
                return
            }
            guard let (wFilter, sRect) = makeWindowFilter(for: scWindow) else { return }
            filter = wFilter
            sourceRect = sRect
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            width = max(2, (Int(scWindow.frame.width * scale) / 2) * 2)
            height = max(2, (Int(scWindow.frame.height * scale) / 2) * 2)
            RecordingPreferences.windowBundleID = scWindow.owningApplication?.bundleIdentifier
            RecordingPreferences.windowTitle = scWindow.title
        }

        let isVirtualChromakey = virtualChromakeyCheck.state == .on
        let isAlphaChannel = alphaChannelCheck.state == .on
        RecordingPreferences.recordingMode = modeSegment.selectedSegment
        RecordingPreferences.presentationMode = presentationModeCheck.state == .on
        RecordingPreferences.virtualChromakeyEnabled = isVirtualChromakey
        RecordingPreferences.alphaChannelEnabled = isAlphaChannel
        RecordingPreferences.audioDeviceUID = audioDevice?.uniqueID
        RecordingPreferences.saveDirectory = outputURL.deletingLastPathComponent()
        RecordingPreferences.keyCastingEnabled = keyCastCheck.state == .on
        if let lifetime = Double(keyCastLifetimeField.stringValue), lifetime > 0 {
            RecordingPreferences.keyCastingLifetime = lifetime
        }
        if let size = Double(keyCastKeyFontField.stringValue), size > 0 {
            RecordingPreferences.keyCastingKeyFontSize = CGFloat(size)
        }
        RecordingPreferences.keyCastingBgColor = keyCastBgColorWell.color
        RecordingPreferences.keyCastingBgOpacity = CGFloat(Double(keyCastBgOpacityField.stringValue) ?? 0.75)
        RecordingPreferences.keyCastingDemoText = keyCastDemoTextField.stringValue

        hideKeyCastPreview()
        orderOut(nil)
        onRecord?(filter, width, height, audioDevice, outputURL, isPresentationMode, sourceRect, isVirtualChromakey, isAlphaChannel)
    }

    private func makeWindowFilter(for scWindow: SCWindow) -> (SCContentFilter, CGRect)? {
        guard let content = shareableContent,
              let display = content.displays.first(where: { $0.frame.intersects(scWindow.frame) })
                  ?? content.displays.first else { return nil }

        let myBundleID = Bundle.main.bundleIdentifier ?? ""
        let teleprompterWindowID = UInt32(teleprompterOverlay?.windowNumber ?? -1)
        let overlayWindows = content.windows.filter {
            $0.owningApplication?.bundleIdentifier == myBundleID &&
            $0.windowID != teleprompterWindowID
        }

        let filter = SCContentFilter(display: display, including: [scWindow] + overlayWindows)

        let dispFrame = display.frame
        let winFrame = scWindow.frame
        let sourceRect = CGRect(
            x: winFrame.minX - dispFrame.minX,
            y: dispFrame.maxY - winFrame.maxY,
            width: winFrame.width,
            height: winFrame.height
        )
        return (filter, sourceRect)
    }

    private func selectedSCWindow() -> SCWindow? {
        let idx = windowPicker.indexOfSelectedItem
        guard idx > 0 else { return nil }
        return windowPicker.item(at: idx)?.representedObject as? SCWindow
    }

    private func showWindowPicker(windows: [SCWindow], audioDevice: AVCaptureDevice?, presentationMode: Bool, virtualChromakey: Bool, alphaChannel: Bool) {
        let overlay = WindowPickerOverlay(windows: windows)
        windowPickerOverlay = overlay
        overlay.completion = { [weak self] scWindow in
            DispatchQueue.main.async {
                self?.windowPickerOverlay = nil
                guard let scWindow = scWindow else {
                    self?.makeKeyAndOrderFront(nil)
                    return
                }
                guard let (wFilter, sRect) = self?.makeWindowFilter(for: scWindow) else { return }
                let scale = NSScreen.main?.backingScaleFactor ?? 2.0
                let width = max(2, (Int(scWindow.frame.width * scale) / 2) * 2)
                let height = max(2, (Int(scWindow.frame.height * scale) / 2) * 2)
                RecordingPreferences.windowBundleID = scWindow.owningApplication?.bundleIdentifier
                RecordingPreferences.windowTitle = scWindow.title
                self?.onRecord?(wFilter, width, height, audioDevice, self?.outputURL ?? URL(fileURLWithPath: ""), presentationMode, sRect, virtualChromakey, alphaChannel)
            }
        }
        overlay.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// NSColorWell inside a .nonactivatingPanel won't open the color picker because
// the app stays inactive. Activating the app first fixes that.
private class ActivatingColorWell: NSColorWell {
    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        super.mouseDown(with: event)
    }
}
