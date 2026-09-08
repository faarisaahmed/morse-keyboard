# Morse Keyboard

A system-wide iOS keyboard that types raw Morse code. Two oversized pads for dot
and dash, plus `letter`, `space`, `return` and `delete`.

Open `MorseKeyboard.xcodeproj` in Xcode, pick the **MorseKeyboard** scheme and run.

Signing is left blank in the project file. To run on a real device, set your own
team under **Signing & Capabilities** for both the **MorseKeyboard** and
**MorseBoard** targets. The simulator needs no signing.

## What each key types

| Key      | Inserts | Meaning                     |
| -------- | ------- | --------------------------- |
| ●        | `.`     | dot                         |
| ▬        | `-`     | dash                        |
| `letter` | `" "`   | end of a letter             |
| `space`  | `" / "` | end of a word               |
| `return` | `"\n"`  | newline                     |
| `delete` | —       | backspace (repeats on hold) |

So `SOS` is typed `... --- ...`, and `SOS SOS` is `... --- ... / ... --- ...`.

Nothing is decoded — what you tap is exactly what lands in the text field.

## No autocorrect, no predictive text

Both come for free, and there are tests pinning them:

- A custom keyboard extension draws its entire input view, so the QuickType /
  predictive bar never appears.
- Text is inserted through `UITextDocumentProxy`, which bypasses the system's
  text substitutions. `...` stays three periods rather than becoming an ellipsis
  (`…`), and `--` stays two hyphens rather than becoming an em dash (`—`).

## Installing the keyboard

Run the app once, then **Settings › General › Keyboard › Keyboards › Add New
Keyboard…** and pick **Morse**. Tap the globe key on any keyboard to switch to it.

"Allow Full Access" is not requested and not needed — the keyboard has no
network or shared-container code.

## Layout

`MorseBoard/KeyboardViewController.swift` holds the whole keyboard. Every
dimension in `Metrics` is a fraction of the screen's short edge, measured off the
reference design, so proportions hold across devices.

The keyboard's own view covers the two key rows only. iOS draws the globe and
dictation bar directly beneath it, and the dark palette is sampled to match the
system keyboard background exactly so the seam is invisible. The palette follows
the host's keyboard appearance, so it is dark in dark mode and light in light
mode.

## Tests

`MorseKeyboardUITests` drives the real extension and asserts on what actually
lands in the text view. The keyboard must be enabled on the target simulator
first:

```sh
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
xcrun simctl spawn "$UDID" pluginkit -e use -i com.faaris.MorseKeyboard.MorseBoard
xcrun simctl spawn "$UDID" defaults write .GlobalPreferences AppleKeyboards \
  -array "com.faaris.MorseKeyboard.MorseBoard" "en_US@sw=QWERTY;hw=Automatic"
xcrun simctl spawn "$UDID" launchctl stop com.apple.SpringBoard
```

Then `xcodebuild test` (or `⌘U` in Xcode). Without this the tests fail fast with
"the Morse keyboard is not the active keyboard on this simulator".
