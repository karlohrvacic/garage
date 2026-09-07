# Running Garage on iOS

Written 7 September 2026, when the iOS project was created. **Nothing here has
been built or run** — this machine has the Command Line Tools, not Xcode, so
every step below is written from the project as it now stands rather than from
a build somebody watched succeed. Treat it as a checklist to verify, not a
report.

What exists after that change:

- `ios/` — the standard Flutter iOS project, bundle id `cc.hrva.garage`
  (the same as Android), display name **Garage**.
- Deployment target **15.0**, not the template's 13.0: Firebase 4.x requires it
  and the mismatch surfaces as a pod install failure, not as a Dart error.
- `Info.plist` carries the location purpose string, the remote-notification
  background mode, the Files-app keys, the three shipped languages, and
  `ITSAppUsesNonExemptEncryption=false` so uploads skip the export questionnaire.
- A `ios` job in `ci.yml` that runs `flutter build ios --release --no-codesign`
  on a macOS runner. **It has never run.** Its first run is the first time
  anything has compiled this project, and it is the cheapest place to find out.

---

## 1. Xcode, then the first build (~1 hour, most of it downloading)

```bash
xcode-select --install          # already done: Command Line Tools are present
# Xcode itself, from the App Store — several GB
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods      # or: brew install cocoapods

flutter doctor                  # should stop complaining about Xcode
flutter build ios --no-codesign
```

> **Without Xcode, `flutter build ios` says `Application not configured for
> iOS`** — which was checked here, and is a misleading sentence: the project is
> configured, the toolchain is missing. `flutter doctor -v` is the one that says
> so plainly. Do not go looking for what is wrong with `ios/`.

**Expect this to fail the first time.** Twenty-odd plugins are about to be
compiled for a platform this project has never targeted. The likely shapes:

- **A pod needs a higher deployment target.** Raise
  `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj` (three
  configurations) *and* uncomment `platform :ios` in the generated `ios/Podfile`
  to match, or CocoaPods and Xcode disagree and only one of them says so.
- **`saf_util` / `saf_stream` have no iOS implementation.** They are Android's
  Storage Access Framework and are already gated behind
  `defaultTargetPlatform == TargetPlatform.android`
  (`lib/core/files/backup_folder_io.dart:19`), so the Dart compiles; if the pod
  step objects, they need `platforms:` in their own pubspec and the fix is a
  conditional dependency, not a code change.
- **`crop_your_image`, `cached_network_image`** — pure Dart or well-supported;
  no reason to expect trouble, which is exactly why they are worth checking.

## 2. A device, without a developer account (~15 minutes)

A free Apple ID signs an app onto your own phone for seven days, which is
enough to answer "does it look right on an iPhone".

- Xcode → Settings → Accounts → add your Apple ID.
- `open ios/Runner.xcworkspace`, select Runner → Signing & Capabilities, tick
  **Automatically manage signing**, pick your personal team.
- `flutter run --profile` with the phone plugged in. Profile, not debug: the
  same reason as the Android emulator.

What to look at first, because it is what differs from Android:

- The **five-tab bottom bar** and whether the Croatian and Italian labels fit.
- **Dates and currency** — iOS resolves locales differently; the app asks for
  `hr` and `it` and the plist now declares them.
- **The share sheet** (export, backup, a report) and whether the file lands
  somewhere the Files app can see it.
- **Notifications**: local reminders need a runtime permission prompt on iOS
  that Android 12 and below did not ask for.

## 3. What needs a paid account (99 USD a year)

Everything below is blocked on it, and none of it can be prepared here:

- **Push.** An APNs authentication key (`.p8`), uploaded to the Firebase iOS
  app, plus the Push Notifications capability. Until then the app's local
  scheduling covers this device only — the same all-or-nothing trap
  [RUNBOOK-push.md](RUNBOOK-push.md) describes for Android.
- **Google sign-in.** The Firebase iOS app produces a `GoogleService-Info.plist`
  and a reversed client id that must go into `Info.plist` as a `CFBundleURLTypes`
  entry. Without it the Google button opens a browser and never comes back.
- **Universal links.** `web/.well-known/assetlinks.json` has an Apple twin,
  `apple-app-site-association`, which needs the **Team ID** — a value that does
  not exist until the account does. Add the Associated Domains capability
  (`applinks:garage.hrva.cc`) at the same time, and not before: the entitlement
  without the matching App ID capability fails signing, which is a confusing
  first error to hit.
- **TestFlight and the App Store.** A second store listing, a second privacy
  questionnaire (the answers are the same as Play's — see
  [play-store-listing.md](play-store-listing.md)), and screenshots at iPhone
  sizes.

## 4. What has no iOS counterpart

- **The home-screen widget.** `android/app/src/main/res/xml/` holds a
  `RemoteViews` widget; iOS wants a WidgetKit extension in Swift, which is a
  separate target and a separate piece of work. The app is complete without it.
- **The fill-up launcher shortcut.** iOS home-screen quick actions are close
  enough to be worth doing later, and are not the same API.
- **Folder backup.** Android's Storage Access Framework has no iOS equivalent;
  `backupFoldersSupported` already returns false everywhere else, and the
  Files-app keys added to `Info.plist` are what iOS offers instead.
