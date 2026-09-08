import XCTest

/// Drives the real Morse keyboard extension and checks what actually lands in
/// the text view.
///
/// The Morse keyboard must be the active keyboard on the target simulator.
/// See README.md for the `pluginkit` command that enables it.
final class MorseKeyboardUITests: XCTestCase {

    private var app: XCUIApplication!
    private var textView: XCUIElement!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        textView = app.textViews.firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 10))
        textView.tap()
        XCTAssertTrue(
            app.keys["dot"].waitForExistence(timeout: 10),
            "the Morse keyboard is not the active keyboard on this simulator"
        )
    }

    private func tap(_ key: String, _ times: Int = 1) {
        for _ in 0..<times { app.keys[key].tap() }
    }

    private var typed: String {
        (textView.value as? String) ?? ""
    }

    /// The headline requirement: what you tap is exactly what you get.
    /// No ellipsis for "...", no em dash for "--".
    func testTypesLiteralDotsAndDashesWithoutSubstitution() {
        tap("dot", 3)
        XCTAssertEqual(typed, "...", "three dots must stay three periods, not an ellipsis")
        XCTAssertFalse(typed.contains("\u{2026}"), "ellipsis substitution leaked in")

        tap("letter")
        tap("dash", 2)
        XCTAssertEqual(typed, "... --", "two dashes must stay two hyphens, not an em dash")
        XCTAssertFalse(typed.contains("\u{2014}"), "em dash substitution leaked in")
        XCTAssertFalse(typed.contains("\u{2013}"), "en dash substitution leaked in")
    }

    /// letter inserts a plain space; space inserts the " / " word separator.
    func testSeparators() {
        tap("dot")
        tap("letter")
        tap("dash")
        XCTAssertEqual(typed, ". -")

        tap("space")
        tap("dot")
        XCTAssertEqual(typed, ". - / .")
    }

    func testReturnInsertsNewline() {
        tap("dot")
        tap("return")
        tap("dash")
        XCTAssertEqual(typed, ".\n-")
    }

    func testDeleteRemovesOneCharacter() {
        tap("dot"); tap("dash"); tap("dot")
        XCTAssertEqual(typed, ".-.")
        tap("delete")
        XCTAssertEqual(typed, ".-")
        tap("delete")
        XCTAssertEqual(typed, ".")
    }

    /// A custom keyboard draws its own view; the QuickType / predictive bar
    /// belongs to the system keyboard and must not be present.
    func testNoPredictiveBarOrAutocorrectSuggestions() {
        tap("dot", 2)
        let predictionBar = app.otherElements["Typing Predictions"]
        XCTAssertFalse(predictionBar.exists, "a predictive text bar is showing")
        XCTAssertEqual(typed, "..", "autocorrect altered the raw input")
    }

    /// iOS supplies the globe and dictation bar beneath a custom keyboard, so
    /// the keyboard must not draw duplicates of its own.
    func testDoesNotDuplicateSystemKeys() {
        XCTAssertFalse(app.keys["dictation"].exists, "keyboard drew its own mic key")
        XCTAssertFalse(
            app.keys["next keyboard"].exists,
            "keyboard drew its own globe while the system already provides one"
        )
    }

    /// The five keys in the reference design, and nothing else.
    func testKeyInventory() {
        let labels = Set(app.keys.allElementsBoundByIndex.map(\.label))
        XCTAssertEqual(labels, ["dot", "dash", "letter", "space", "return", "delete"])
    }
}
