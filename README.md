# Boxing Timer

A private native iPhone boxing timer, built with SwiftUI. Dark navy, red accents, oversized Anton numerals, and bottom-aligned workout controls follow the approved Corner design.

- Configurable rounds, round duration, rest, and preparation; settings save automatically.
- Preparation → rounds and rests → completion, without a rest after the final round.
- Pause/resume, confirmation before ending, repeat, and a work/rest summary.
- Active rounds fill the screen with primary red and navy text and controls for visibility at a distance. Rest, preparation, pause, setup, and completion retain the navy background.
- Recorded bell patterns: one strike starts a round, two quick strikes (0.25 seconds apart) begin rest, and two slower strikes (0.8 seconds apart) finish the workout. Three-second preparation/rest countdown beeps mix with the bells and other audio. With zero rest, each new round gets only its start strike.
- Scheduled audio drives the workout clock. Cues are queued before starting, including after resuming, rather than depending on background UI timers.
- Screen stays awake during a running workout. Calls, disconnected headphones, and audio-engine interruptions pause the session for explicit resumption.

No third-party code dependencies, accounts, analytics, or network access.

## Development

Open `BoxingTimer.xcodeproj` in Xcode and run the `BoxingTimer` scheme on an iPhone simulator. The deployment target is iOS 26.0 and the first version supports portrait orientation.

For a physical iPhone:

1. Connect the iPhone, trust the Mac, and enable Developer Mode on the phone when prompted.
2. Add your Apple account in Xcode Settings → Accounts.
3. In the app target's Signing & Capabilities, select your Personal Team. The bundle identifier `com.martindzejky.BoxingTimer` is provisional; change it if your account requires it.
4. Select the connected phone as the run destination and run the app.

The project records a Personal Team identifier; signing certificates and credentials stay on your Mac. Physical-device signing, exact iOS compatibility, locked-screen bells, Bluetooth output, and mixing with music must be checked on the actual phone. Simulator checks do not establish those hardware behaviors.

## Verification

```sh
xcodebuild -project BoxingTimer.xcodeproj -scheme BoxingTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project BoxingTimer.xcodeproj -scheme BoxingTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build -collect-test-diagnostics never -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcrun swift-format lint --strict --recursive BoxingTimer BoxingTimerTests BoxingTimerUITests scripts
git diff --check
```

Swift Testing covers interval boundaries, clock catch-up, no-preparation/no-rest/single-round sessions, cue ordering, and saved configuration validation. XCUITest exercises setup, sound preview, fixed countdown geometry as digits change, pause/resume, Home Screen transitions, completion/repeat, end/cancel, and persistence after relaunch. Tests attach screenshots to the Xcode result bundle. Debug-only `--ui-testing` uses a short workout for end-to-end tests; release builds ignore it.

## Assets

- `Design/boxing-glove.svg` is the editable red glove icon, based on the supplied PNG reference. The app icon uses an opaque 1024×1024 PNG export. Regenerate from the repository root with `swift scripts/render-icon.swift` (macOS system WebKit, no extra dependencies).
- Anton is bundled under the SIL Open Font License in `BoxingTimer/Resources/Anton-OFL.txt`, sourced from [Google Fonts](https://github.com/google/fonts/tree/main/ofl/anton).
- The single-strike bell in `BoxingTimer/Resources/boxing-bell.wav` was supplied by Martin from ElevenLabs. Its full two-second decay is preserved; the file is converted to mono 44.1 kHz PCM for playback. Countdown beeps are synthesized in `WorkoutAudio.swift`.

## License

Source code is available under the [MIT License](LICENSE). The bundled Anton font retains its [SIL Open Font License](BoxingTimer/Resources/Anton-OFL.txt).
