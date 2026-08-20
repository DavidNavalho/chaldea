# Session Handoff

Use this file to resume work from another computer after `git pull`.
Update it at the end of each working session.

## Current Purpose
- This fork tracks upstream `chaldea` and adds automation-focused features:
  - Laplace Auto 3T team identification/search
  - Shared Teams "My Box" compatibility and batch simulation tools
  - My Box Coverage overview page
- Design constraint: keep upstream-core changes minimal and keep custom logic in
  `lib/custom/...` whenever possible.

## TestFlight Runbook
- Complete iOS signing, App Store Connect, upload, and TestFlight instructions:
  `TESTFLIGHT_RUNBOOK.md`

## Quick Resume Checklist
1. `git fetch --all --prune`
2. `git checkout main`
3. `git pull origin main`
4. If needed, sync with upstream:
   - `./scripts/sync_fork_pr.sh --open-pr`
   - legacy (if needed): `./scripts/sync_fork.sh`
5. Install deps if needed:
   - `brew install fvm`
   - `fvm install 3.41.7 && fvm use 3.41.7`
   - `fvm flutter pub get`
   - `fvm flutter precache --ios`
   - `(cd ios && pod install)`
6. Launch app:
   - `fvm flutter run -d macos`

## Last Session Snapshot
- Date: 2026-08-20
- Branch: sharp-ocean
- Last commit: this branch's TestFlight preparation commit (run `git log -1 --oneline` for the current hash)
- Working tree status: expected clean after committing this snapshot
- Active feature(s): personal iOS bundle/team/App Group configuration for this fork; TestFlight setup complete
- What is done:
  - added the fork identity settings in `ios/Flutter/ForkIdentity.xcconfig`
  - switched the iOS app and widget targets to the personal Team ID and bundle IDs
  - added fork-specific entitlements using a personal App Group and without the upstream universal-link claim
  - routed the widget's Dart and Swift shared-container access through isolated fork identity files
  - verified resolved Xcode settings and entitlement plist syntax
  - installed FVM 4.1.2 through Homebrew and Flutter 3.41.7 through FVM
  - aligned `.fvmrc` with `pubspec.yaml`
  - completed `fvm flutter pub get`, iOS precache, and `pod install`
  - replaced Xcode 27 beta 1 with Xcode 27 beta 5 (`27A5237l`) and selected
    `/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer`
  - added a fork-scoped iOS 15 minimum and applied the same floor to all CocoaPods targets
  - adapted the renamed native folder to Flutter 3.41's generated plugin registrant location
  - synchronized the widget version/build with the containing Flutter app
  - registered the personal App Group and both App IDs under team `WAF9PC2Y8K`
  - associated both App IDs with `group.io.github.davidnavalho.chaldea.shared`
  - created the App Store Connect app `Chaldea Personal` (app ID `6801619927`)
  - built and validated the signed release archive at `build/ios/archive/Chaldea.xcarchive`
    - app: Chaldea 2.5.27 (990), bundle `io.github.davidnavalho.chaldea`, minimum iOS 15.0
    - widget: 2.5.27 (990), bundle `io.github.davidnavalho.chaldea.FakerStatusWidget`, minimum iOS 18.1
  - uploaded build 989 successfully through Xcode Organizer using beta 5
  - confirmed App Store Connect processed build 989 as `Ready to Submit`
  - created internal TestFlight group `Chaldea Internal` with automatic distribution enabled
  - added the owner's App Store Connect account as the sole internal tester
  - diagnosed build 989's NA account-login failure as the known upstream wrong-game-top bug
  - applied upstream commit `b3a096eb8` exactly across its three original files
    - NA metadata now uses `tops.of(user.region)` instead of `tops.jp`
    - region-info requests preserve the selected region
    - Account File login fetches fresh game metadata instead of retaining stale page state
  - built, signed, and exported `2.5.27 (990)` with a build-number override
  - validated build 990's app/widget signatures, Team ID, bundle IDs, versions, and App Group entitlements
  - uploaded build 990; App Store Connect shows it `Complete`, `Ready to Submit`, and in `Chaldea Internal`
  - installed build 990 from TestFlight and confirmed that NA Account File login now succeeds on-device
  - added `TESTFLIGHT_RUNBOOK.md` as the complete owner/agent continuation guide
- What is next:
  - verify shared App Group data and the widget on a device where the widget is available
  - use a build number above 990 for the next App Store Connect upload
- Known blockers:
  - no remaining blocker for internal TestFlight installation or NA Account File login
  - Xcode Organizer reports a non-blocking missing dSYM warning for `objective_c.framework`; Apple accepted the upload
  - build 989 has the upstream NA metadata bug and should not be used for NA account login; build 990 supersedes it
  - a stable Xcode may still be required for a future production App Store release
  - tests run with `--dart-define=APP_PATH=/path/to/repository`, but six suites require an offline game-data payload that is not present in this worktree (14 tests pass before those data-loading failures)
## Files Touched In Current Workstream
- `ios/Chaldea.xcodeproj/project.pbxproj`
- `ios/Chaldea/Chaldea-Bridging-Header.h`
- `ios/Flutter/ForkIdentity.xcconfig`
- `ios/Chaldea/Fork.entitlements`
- `ios/FakerStatusWidgetExtension.fork.entitlements`
- `ios/FakerStatusWidget/ForkIdentity.swift`
- `ios/FakerStatusWidget/FakerStatusWidget.swift`
- `ios/Podfile`
- `ios/Podfile.lock`
- `lib/custom/ios/fork_identity.dart`
- `lib/app/api/atlas.dart`
- `lib/app/modules/import_data/autologin/autologin_page.dart`
- `lib/models/faker/jp/agent.dart`
- `lib/packages/home_widget.dart`
- `.fvmrc`
- `HANDOFF.md`
- `TESTFLIGHT_RUNBOOK.md`

## Validation Commands
- `xcodebuild -workspace ios/Chaldea.xcworkspace -scheme Runner -configuration Release -showBuildSettings`
- `xcodebuild -workspace ios/Chaldea.xcworkspace -scheme FakerStatusWidgetExtension -configuration Release -showBuildSettings`
- `plutil -lint ios/Chaldea/Fork.entitlements ios/FakerStatusWidgetExtension.fork.entitlements`
- `ruby -c ios/Podfile`
- `fvm flutter build ipa --release --no-codesign`
- `fvm flutter analyze`
- `fvm flutter test --dart-define=APP_PATH=/path/to/repository`
- `fvm flutter build macos --debug`

## Notes For Safe Upstream Updates
- Prefer `./scripts/sync_fork_pr.sh --open-pr` for protected-main syncs; use `./scripts/sync_fork.sh` only for manual/non-protected flows.
- For machine-driven automation, prefer the new `scripts/fork/` entrypoints over the human wrapper when finer control is needed.
- Resolve conflicts by preserving upstream behavior first, then re-apply custom
  integration hooks.
- Re-check custom module wiring after any upstream UI changes in battle modules.
