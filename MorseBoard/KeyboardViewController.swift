import UIKit

/// A Morse code keyboard that types raw Morse into the host text field.
///
/// Nothing is decoded or transformed. The dot and dash keys insert literal
/// "." and "-" characters, `letter` inserts a single space, `space` inserts
/// " / " (the conventional Morse word separator), and `return` inserts a
/// newline. Because a keyboard extension inserts text through
/// `UITextDocumentProxy`, none of the system text substitutions run: "..."
/// never becomes an ellipsis and "--" never becomes an em dash.
final class KeyboardViewController: UIInputViewController {

    // MARK: - Design constants

    /// The dark values are sampled from the reference design, and match the
    /// system keyboard background exactly so the globe / dictation bar iOS
    /// draws beneath us blends in seamlessly. The light values are their
    /// counterparts from the stock light keyboard.
    fileprivate struct Palette {
        let background: UIColor
        let key: UIColor
        let keyDark: UIColor
        let glyph: UIColor

        static let dark = Palette(
            background: .rgb(43, 43, 43),
            key: .rgb(106, 106, 106),
            keyDark: .rgb(70, 70, 70),
            glyph: .white
        )

        static let light = Palette(
            background: .rgb(209, 212, 217),
            key: .white,
            keyDark: .rgb(172, 178, 189),
            glyph: .black
        )
    }

    /// Every dimension is a fraction of the screen's short edge, measured off
    /// the reference design, so the proportions hold on any device.
    private struct Metrics {
        let base: CGFloat

        init() {
            let bounds = UIScreen.main.bounds
            // Capped at the widest iPhone so an iPad does not get a keyboard
            // half the height of the screen.
            base = min(min(bounds.width, bounds.height), 430)
        }

        /// Height of the keyboard's own view. iOS adds its globe / dictation
        /// bar below this, which together match the reference design's total.
        var contentHeight: CGFloat { base * 0.6396 }
        var edgeInset: CGFloat { base * 0.0102 }
        var keyGap: CGFloat { base * 0.0102 }
        var commandRowHeight: CGFloat { base * 0.1105 }
        /// Only used on the rare configurations where iOS does not supply a
        /// keyboard-switch key of its own.
        var globeRowHeight: CGFloat { base * 0.1170 }
        var gapBeforeGlobeRow: CGFloat { base * 0.0370 }
        var cornerRadius: CGFloat { base * 0.0127 }
        var commandFontSize: CGFloat { commandRowHeight * 0.40 }
        var symbolPointSize: CGFloat { base * 0.0639 }
    }

    /// Glyph sizes as a fraction of the width of the pad they sit in.
    private enum Glyph {
        static let dotDiameter: CGFloat = 0.0851
        static let dashWidth: CGFloat = 0.2445
        static let dashHeight: CGFloat = 0.0611
    }

    /// Relative widths of the command row, left to right. `letter` is trimmed
    /// down from the reference layout to make room for `delete` on the right.
    private static let commandWidths: [CGFloat] = [0.32, 0.26, 0.22, 0.20]

    // MARK: - What each key inserts

    private static let dotText = "."
    private static let dashText = "-"
    private static let letterSeparator = " "
    private static let wordSeparator = " / "
    private static let newline = "\n"

    // MARK: - State

    private let metrics = Metrics()
    private var keys: [KeyView] = []
    private var globeRow: UIView!
    private var totalHeight: NSLayoutConstraint!
    private var globeRowHeight: NSLayoutConstraint!
    private var gapBeforeGlobeRow: NSLayoutConstraint!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        applyPalette()
    }

    override func viewWillLayoutSubviews() {
        // iOS normally draws its own globe and dictation bar directly beneath a
        // custom keyboard, so we contribute nothing there. Only where it does
        // not (`needsInputModeSwitchKey`) do we open up a row of our own.
        let needsOwnGlobe = needsInputModeSwitchKey
        globeRow.isHidden = !needsOwnGlobe
        globeRowHeight.constant = needsOwnGlobe ? metrics.globeRowHeight : 0
        gapBeforeGlobeRow.constant = needsOwnGlobe ? metrics.gapBeforeGlobeRow : 0
        totalHeight.constant = metrics.contentHeight
            + (needsOwnGlobe ? metrics.globeRowHeight + metrics.gapBeforeGlobeRow : 0)
        super.viewWillLayoutSubviews()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        applyPalette()
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyPalette()
    }

    /// A host can ask for a dark keyboard inside an otherwise light app, so the
    /// document's requested appearance wins over the trait collection.
    private func applyPalette() {
        let isDark: Bool
        switch textDocumentProxy.keyboardAppearance {
        case .dark: isDark = true
        case .light: isDark = false
        default: isDark = traitCollection.userInterfaceStyle == .dark
        }

        let palette = isDark ? Palette.dark : Palette.light
        view.backgroundColor = palette.background
        for key in keys { key.apply(palette) }
    }

    // MARK: - Layout

    private func buildLayout() {
        totalHeight = view.heightAnchor.constraint(equalToConstant: metrics.contentHeight)
        // Just under required so the system can still resize us during rotation
        // without producing an unsatisfiable-constraint log.
        totalHeight.priority = UILayoutPriority(999)
        totalHeight.isActive = true

        let strokeRow = buildStrokeRow()
        let commandRow = buildCommandRow()
        globeRow = buildGlobeRow()

        for row in [strokeRow, commandRow, globeRow!] {
            row.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(row)
        }

        let guide = view.safeAreaLayoutGuide
        globeRowHeight = globeRow.heightAnchor.constraint(equalToConstant: 0)
        gapBeforeGlobeRow = globeRow.topAnchor.constraint(
            equalTo: commandRow.bottomAnchor, constant: 0)

        NSLayoutConstraint.activate([
            strokeRow.topAnchor.constraint(equalTo: view.topAnchor, constant: metrics.edgeInset),
            strokeRow.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: metrics.edgeInset),
            strokeRow.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -metrics.edgeInset),

            commandRow.topAnchor.constraint(equalTo: strokeRow.bottomAnchor, constant: metrics.keyGap),
            commandRow.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: metrics.edgeInset),
            commandRow.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -metrics.edgeInset),
            commandRow.heightAnchor.constraint(equalToConstant: metrics.commandRowHeight),

            gapBeforeGlobeRow,
            globeRowHeight,
            globeRow.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: metrics.edgeInset),
            globeRow.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -metrics.edgeInset),
            // Collapses onto the command row's bottom edge when unused.
            globeRow.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// The two oversized dot / dash pads.
    private func buildStrokeRow() -> UIView {
        let row = UIView()

        let dot = makeKey(.primary, label: "dot", action: #selector(dotTapped))
        let dash = makeKey(.primary, label: "dash", action: #selector(dashTapped))

        for key in [dot, dash] {
            key.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(key)
        }

        NSLayoutConstraint.activate([
            dot.topAnchor.constraint(equalTo: row.topAnchor),
            dot.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            dot.leadingAnchor.constraint(equalTo: row.leadingAnchor),

            dash.topAnchor.constraint(equalTo: row.topAnchor),
            dash.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            dash.trailingAnchor.constraint(equalTo: row.trailingAnchor),

            dash.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: metrics.keyGap),
            dash.widthAnchor.constraint(equalTo: dot.widthAnchor),
        ])

        dot.addStrokeGlyph(widthRatio: Glyph.dotDiameter, heightRatio: Glyph.dotDiameter, rounded: true)
        dash.addStrokeGlyph(widthRatio: Glyph.dashWidth, heightRatio: Glyph.dashHeight, rounded: false)
        return row
    }

    /// letter · space · return · delete
    private func buildCommandRow() -> UIView {
        let row = UIView()

        let letter = makeKey(.primary, label: "letter", action: #selector(letterTapped))
        letter.setTitle("letter", size: metrics.commandFontSize)

        let space = makeKey(.primary, label: "space", action: #selector(spaceTapped))
        space.setTitle("space", size: metrics.commandFontSize)

        let returnKey = makeKey(.secondary, label: "return", action: #selector(returnTapped))
        returnKey.setTitle("return", size: metrics.commandFontSize)

        let delete = makeKey(.secondary, label: "delete", action: #selector(deleteTapped))
        delete.setSymbol("delete.left", pointSize: metrics.commandFontSize * 1.15)
        delete.onRepeat = { [weak self] in self?.deleteTapped() }

        let rowKeys = [letter, space, returnKey, delete]

        for key in rowKeys {
            key.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(key)
            key.topAnchor.constraint(equalTo: row.topAnchor).isActive = true
            key.bottomAnchor.constraint(equalTo: row.bottomAnchor).isActive = true
        }

        // The three inter-key gaps come out of the total width before the
        // proportional split, charged to each key by its share.
        let gapAllowance = metrics.keyGap * CGFloat(rowKeys.count - 1)
        for (key, fraction) in zip(rowKeys, Self.commandWidths) {
            key.widthAnchor.constraint(
                equalTo: row.widthAnchor,
                multiplier: fraction,
                constant: -gapAllowance * fraction
            ).isActive = true
        }

        rowKeys[0].leadingAnchor.constraint(equalTo: row.leadingAnchor).isActive = true
        for (previous, next) in zip(rowKeys, rowKeys.dropFirst()) {
            next.leadingAnchor.constraint(
                equalTo: previous.trailingAnchor, constant: metrics.keyGap
            ).isActive = true
        }

        return row
    }

    /// A fallback keyboard-switch key, used only where iOS does not provide one.
    /// It stays collapsed on iPhone, where the system draws its own globe and
    /// dictation bar directly beneath us.
    private func buildGlobeRow() -> UIView {
        let row = UIView()
        row.clipsToBounds = true

        let globe = makeKey(.plain, label: "next keyboard", action: nil)
        globe.setSymbol("globe", pointSize: metrics.symbolPointSize)
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        globe.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(globe)

        NSLayoutConstraint.activate([
            globe.topAnchor.constraint(equalTo: row.topAnchor),
            globe.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            globe.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: metrics.edgeInset * 3),
            globe.widthAnchor.constraint(equalToConstant: metrics.globeRowHeight),
        ])
        return row
    }

    private func makeKey(_ role: KeyView.Role, label: String, action: Selector?) -> KeyView {
        let key = KeyView(role: role, cornerRadius: role == .plain ? 0 : metrics.cornerRadius)
        key.accessibilityLabel = label
        if let action {
            key.addTarget(self, action: action, for: .touchUpInside)
        }
        keys.append(key)
        return key
    }

    // MARK: - Key actions

    @objc private func dotTapped() { insert(Self.dotText) }
    @objc private func dashTapped() { insert(Self.dashText) }
    @objc private func letterTapped() { insert(Self.letterSeparator) }
    @objc private func spaceTapped() { insert(Self.wordSeparator) }
    @objc private func returnTapped() { insert(Self.newline) }

    @objc private func deleteTapped() {
        textDocumentProxy.deleteBackward()
        UIDevice.current.playInputClick()
    }

    private func insert(_ text: String) {
        textDocumentProxy.insertText(text)
        UIDevice.current.playInputClick()
    }
}

// MARK: - Key view

/// A flat rounded key that dims while held. Used for every key on the board.
private final class KeyView: UIControl {

    enum Role {
        /// dot, dash, letter, space
        case primary
        /// return, delete — the darker shade
        case secondary
        /// the globe, drawn straight onto the background
        case plain
    }

    /// Fired repeatedly while the key is held, after an initial delay.
    /// Only wired up for delete.
    var onRepeat: (() -> Void)?

    private let role: Role
    private var normalColor: UIColor = .clear
    private let label = UILabel()
    private let imageView = UIImageView()
    private var strokeGlyph: UIView?
    private var repeatTimer: Timer?

    init(role: Role, cornerRadius: CGFloat) {
        self.role = role
        super.init(frame: .zero)

        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey

        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        imageView.contentMode = .center
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addTarget(self, action: #selector(beginRepeat), for: .touchDown)
        for event in [UIControl.Event.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit] {
            addTarget(self, action: #selector(endRepeat), for: event)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet {
            guard role != .plain else {
                alpha = isHighlighted ? 0.4 : 1
                return
            }
            backgroundColor = isHighlighted ? normalColor.withAlphaComponent(0.6) : normalColor
        }
    }

    func setTitle(_ text: String, size: CGFloat) {
        label.text = text
        label.font = .systemFont(ofSize: size, weight: .regular)
    }

    func setSymbol(_ name: String, pointSize: CGFloat) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        imageView.image = UIImage(systemName: name, withConfiguration: config)
    }

    /// Adds the plain dot or dash, sized as a fraction of the key's width so it
    /// scales with the device.
    func addStrokeGlyph(widthRatio: CGFloat, heightRatio: CGFloat, rounded: Bool) {
        let glyph = UIView()
        // Without this the glyph wins the hit test and swallows taps aimed at
        // the middle of the pad — the most natural place to press.
        glyph.isUserInteractionEnabled = false
        glyph.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glyph)
        strokeGlyph = glyph
        isRoundGlyph = rounded

        NSLayoutConstraint.activate([
            glyph.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
            glyph.widthAnchor.constraint(equalTo: widthAnchor, multiplier: widthRatio),
            glyph.heightAnchor.constraint(equalTo: widthAnchor, multiplier: heightRatio),
        ])

        if !rounded { glyph.layer.cornerRadius = 1 }
    }

    private var isRoundGlyph = false

    override func layoutSubviews() {
        super.layoutSubviews()
        if isRoundGlyph, let glyph = strokeGlyph {
            glyph.layer.cornerRadius = glyph.bounds.height / 2
        }
    }

    // MARK: Appearance

    func apply(_ palette: KeyboardViewController.Palette) {
        switch role {
        case .primary: normalColor = palette.key
        case .secondary: normalColor = palette.keyDark
        case .plain: normalColor = .clear
        }
        backgroundColor = normalColor
        label.textColor = palette.glyph
        imageView.tintColor = palette.glyph
        strokeGlyph?.backgroundColor = palette.glyph
    }

    // MARK: Key repeat

    @objc private func beginRepeat() {
        guard onRepeat != nil else { return }
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in
                self?.onRepeat?()
            }
        }
    }

    @objc private func endRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

private extension UIColor {
    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }
}
