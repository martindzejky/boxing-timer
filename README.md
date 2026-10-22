# Boxing Timer

A private iPhone boxing timer. This repository currently contains only the standard SwiftUI starter screen; timer features and design come next.

## Development

Open `BoxingTimer.xcodeproj` in Xcode and run the `BoxingTimer` scheme on an iPhone simulator.

The initial deployment target is iOS 26.0, matching the installed simulator runtime. Confirm the physical iPhone's iOS version before device installation.

For your iPhone, choose your Apple account's Personal Team under Signing & Capabilities. The bundle identifier `com.martindzejky.BoxingTimer` is provisional; change it if your account requires it. No team or signing credentials are stored in this repository.

## Verification

```sh
xcodebuild -project BoxingTimer.xcodeproj -scheme BoxingTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
xcrun swift-format lint --strict --recursive BoxingTimer
git diff --check
```

There are no third-party dependencies or tests yet.
