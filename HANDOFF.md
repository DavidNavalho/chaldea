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
   - `fvm install 3.44.8 && fvm use 3.44.8`
   - `fvm flutter pub get`
   - `fvm flutter precache --ios`
   - `(cd ios && pod install)`
6. Launch app:
   - `fvm flutter run -d macos`

## Last Session Snapshot
- Date: 2026-08-22
- Branch: `automation/xcode-cloud-pr-validation`
- Last commit: run `git log -1 --oneline` for the current hash
- Working tree status: expected clean after committing and pushing the Xcode
  Cloud automation branch
- Active feature(s): Xcode Cloud PR validation and protected TestFlight delivery
- What is done:
  - merged `upstream/main` (2.6.0) into the fork from the updated `origin/main`
  - resolved the two merge conflicts by retaining all upstream Xcode/auth
    changes and reapplying only the two registrant paths and two My Box imports
  - updated `.fvmrc` to upstream's required Flutter 3.44.8 / Dart 3.12.2
  - installed Flutter 3.44.8 under `/Volumes/mini-ssd/DevData/FVM`; the older
    internal Flutter 3.41.7 installation remains untouched
  - extended the fork-only iOS preparer for Flutter 3.44's generated Swift
    package targets and product wrappers without changing the upstream Podfile
  - validated an unsigned 2.6.0 (990) archive on Xcode 27 beta 5
    - app: bundle `io.github.davidnavalho.chaldea`, minimum iOS 15.0
    - widget: bundle `io.github.davidnavalho.chaldea.FakerStatusWidget`, minimum iOS 18.1
    - compiled app contains the personal App Group and not the upstream default
  - merged the upstream 2.6.0 sync PR into `main` as commit `276a47800`
  - added fork-only Xcode Cloud scripts under `ios/ci_scripts/` without
    changing any upstream workflow or Xcode project file
    - post-clone: pinned Flutter setup, build-number configuration, CocoaPods,
      and generated dependency preparation
    - pre-build: fail-closed main-app and widget identity verification
    - post-build: signed archive, version, deployment, and entitlement checks
  - proved locally that `XCODE_XCCONFIG_FILE` applies the personal identity as
    a highest-priority overlay without editing `project.pbxproj`
  - locally prepared Cloud build number 991 and verified the resolved app and
    widget build settings
  - validated the existing signed 2.5.27 (990) archive with the new Cloud
    post-build validator
  - connected `DavidNavalho/chaldea` to Xcode Cloud without committing an
    Xcode project mutation
  - added the shared Xcode Cloud product manifest under
    `ios/Chaldea.xcodeproj/xcshareddata/xcodecloud/`
  - created the delivery workflow `Main TestFlight Delivery`
    (`cae29f8a-2bfa-4830-beec-bb88072853c9`)
    - manual start for any branch
    - automatic branch-change start for `main`, with auto-cancel enabled
    - Archive `Runner` for iOS
    - Latest Beta or Release Xcode and Latest Release macOS
    - internal TestFlight distribution to `Chaldea Internal`
  - deactivated the earlier bootstrap workflow `Manual TestFlight`
    (`08697A88-8BA0-452D-87DD-923F8A0645B3`)
  - completed Xcode Cloud build 5 from commit `cf6ca61e2` on 2026-08-22
    - Xcode 27 beta 5 / macOS Tahoe 26.6.2
    - archive and App Store export succeeded
    - fork post-clone, identity preflight, and archive validation all passed
    - internal TestFlight post-action succeeded
  - confirmed App Store Connect processed `2.6.0 (5)` as Complete and Testing
    and assigned it to `Chaldea Internal`
  - merged Xcode Cloud automation PR #26 into `main` as `55b1d2280`
  - automatic Xcode Cloud delivery started for that merge
  - created and activated the `PR Validation` workflow
    (`2bf09f44-4d89-45dd-9211-281187afcf66`)
    - pull-request changes from any source branch into `main`
    - auto-cancel superseded builds
    - Build `Runner` for iOS with no distribution or post-action
    - fork-only post-clone validation runs Flutter analysis and the full test suite
  - opened draft PR #27 for the isolated PR-validation hook and helper
  - completed Xcode Cloud PR build 7 from commit `1f5424956`
    - the same 15 informational analysis lints were non-fatal
    - all 254 Flutter tests passed with Cloud-only offline game data
    - the subsequent iOS build passed in 5m42s
  - created active GitHub ruleset `xcode-cloud-pr-validation` (`21213751`)
    for the default branch, requiring `Chaldea | PR Validation` with no bypass
  - full analysis has no errors or warnings and the same 15 informational lints
  - `test/custom/box_coverage/box_coverage_service_test.dart` passes (2 tests)
  - isolated the fork identity settings in
    `ios/Flutter/ForkIdentity.xcconfig`, supplied externally with
    `xcodebuild -xcconfig` rather than wiring them into the upstream project
  - reduced the complete Xcode project PR diff to two generated-registrant path
    corrections; all identity, signing, entitlement, deployment, and version
    edits were removed from the project file
  - restored `ios/Podfile` and `ios/Podfile.lock` to exact upstream contents
  - added `scripts/fork/prepare_ios_testflight.rb` to update only ignored
    CocoaPods build output for Xcode 27 and generate an ignored per-target map
  - added `scripts/fork/build_ios_testflight.sh` as the fork-only archive entry
    point; it applies the identity overlay and validates archive metadata
  - added fork-specific entitlements using a personal App Group and without the upstream universal-link claim
  - changed the one Dart App Group statement to use the build-time
    `CHALDEA_IOS_APP_GROUP_ID`, with the upstream App Group retained as default
  - kept the one Swift widget adapter plus the fork-only Swift identity file
  - kept the one bridging-header correction and the matching two Xcode project
    file-reference corrections for Flutter's generated registrant
  - verified resolved Xcode settings and entitlement plist syntax
  - installed FVM 4.1.2 through Homebrew; Flutter SDKs are managed through FVM
  - aligned `.fvmrc` with `pubspec.yaml`
  - completed `fvm flutter pub get`, iOS precache, and `pod install`
  - replaced Xcode 27 beta 1 with Xcode 27 beta 5 (`27A5237l`) and selected
    `/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer`
  - applied the fork-scoped iOS 15 workaround only to ignored generated
    CocoaPods/Swift-package output
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
  - ran both unsigned and signed end-to-end archives with the new wrapper on
    Xcode 27 beta 5
    - app: Chaldea 2.5.27 (990), bundle
      `io.github.davidnavalho.chaldea`, minimum iOS 15.0
    - widget: 2.5.27 (990), bundle
      `io.github.davidnavalho.chaldea.FakerStatusWidget`, minimum iOS 18.1
    - signed identifiers use team `WAF9PC2Y8K`; both signed entitlements contain
      only `group.io.github.davidnavalho.chaldea.shared`
    - compiled Flutter binary contains the personal App Group and not the
      upstream App Group
    - temporary validation archives were built on the external SSD and moved
      to that drive's Trash; the existing archive was not changed
  - `fvm dart analyze lib/packages/home_widget.dart`, syntax/plist checks, and
    `git diff --check` pass
- What is next:
  - review and merge draft PR #27 after its final Xcode Cloud check passes
  - confirm the merge starts `Main TestFlight Delivery` and not another PR
    validation run
  - install `2.6.0 (5)` from TestFlight and smoke-test the app on-device
  - verify shared App Group data and the widget on a device where the widget is available
- Known blockers:
  - no remaining blocker for Xcode Cloud archive or internal TestFlight delivery
  - no remaining blocker for internal TestFlight installation or NA Account File login
  - Xcode Organizer reports a non-blocking missing dSYM warning for `objective_c.framework`; Apple accepted the upload
  - build 989 has the upstream NA metadata bug and should not be used for NA account login; build 990 supersedes it
  - a stable Xcode may still be required for a future production App Store release
  - Flutter warns that four plugins do not yet support Swift Package Manager;
    Flutter 3.44 falls back to CocoaPods for them, but a future Flutter may stop
    accepting that fallback
  - local full tests require an offline game-data payload that is not present in
    this worktree; `PR Validation` clones it only into Xcode Cloud's temporary machine

## Files Touched In Current Workstream
- `ios/Chaldea.xcodeproj/project.pbxproj`
- `ios/Chaldea/Chaldea-Bridging-Header.h`
- `ios/Flutter/ForkIdentity.xcconfig`
- `ios/Chaldea/Fork.entitlements`
- `ios/FakerStatusWidgetExtension.fork.entitlements`
- `ios/FakerStatusWidget/ForkIdentity.swift`
- `ios/FakerStatusWidget/FakerStatusWidget.swift`
- `lib/app/api/atlas.dart`
- `lib/app/modules/import_data/autologin/autologin_page.dart`
- `lib/models/faker/jp/agent.dart`
- `lib/packages/home_widget.dart`
- `scripts/fork/build_ios_testflight.sh`
- `scripts/fork/prepare_ios_testflight.rb`
- `ios/ci_scripts/README.md`
- `ios/ci_scripts/ci_post_clone.sh`
- `ios/ci_scripts/ci_validate_pull_request.sh`
- `ios/ci_scripts/ci_pre_xcodebuild.sh`
- `ios/ci_scripts/ci_post_xcodebuild.sh`
- `ios/Chaldea.xcodeproj/xcshareddata/xcodecloud/manifest.json`
- `.fvmrc`
- `HANDOFF.md`
- `TESTFLIGHT_RUNBOOK.md`

## Validation Commands
- `scripts/fork/build_ios_testflight.sh --build-name 2.6.0 --build-number 990`
- `scripts/fork/build_ios_testflight.sh --build-name 2.6.0 --build-number 991 --codesign`
- `xcodebuild -workspace ios/Chaldea.xcworkspace -scheme Runner -configuration Release -xcconfig ios/Flutter/ForkIdentity.xcconfig -showBuildSettings`
- `xcodebuild -workspace ios/Chaldea.xcworkspace -scheme FakerStatusWidgetExtension -configuration Release -xcconfig ios/Flutter/ForkIdentity.xcconfig -showBuildSettings`
- `plutil -lint ios/Chaldea/Fork.entitlements ios/FakerStatusWidgetExtension.fork.entitlements`
- `ruby -c ios/Podfile`
- `bash -n scripts/fork/build_ios_testflight.sh`
- `ruby -c scripts/fork/prepare_ios_testflight.rb`
- `bash -n ios/ci_scripts/ci_post_clone.sh ios/ci_scripts/ci_pre_xcodebuild.sh ios/ci_scripts/ci_post_xcodebuild.sh`
- `CI_XCODE_CLOUD=TRUE CI_PRIMARY_REPOSITORY_PATH="$PWD" CI_BUILD_NUMBER=5 CHALDEA_XCODE_CLOUD_MIN_BUILD_NUMBER=1 XCODE_XCCONFIG_FILE="$PWD/ios/Flutter/ForkIdentity.xcconfig" ios/ci_scripts/ci_post_clone.sh`
- `CI_XCODE_CLOUD=TRUE CI_PRIMARY_REPOSITORY_PATH="$PWD" CI_BUILD_NUMBER=5 CHALDEA_XCODE_CLOUD_MIN_BUILD_NUMBER=1 CI_XCODEBUILD_ACTION=archive XCODE_XCCONFIG_FILE="$PWD/ios/Flutter/ForkIdentity.xcconfig" ios/ci_scripts/ci_pre_xcodebuild.sh`
- `fvm dart analyze lib/packages/home_widget.dart`
- `fvm flutter analyze`
- `fvm flutter test --dart-define=APP_PATH=/path/to/repository`
- `fvm flutter build macos --debug`

## Notes For Safe Upstream Updates
- Prefer `./scripts/sync_fork_pr.sh --open-pr` for protected-main syncs; use `./scripts/sync_fork.sh` only for manual/non-protected flows.
- For machine-driven automation, prefer the new `scripts/fork/` entrypoints over the human wrapper when finer control is needed.
- Resolve conflicts by preserving upstream behavior first, then re-apply custom
  integration hooks.
- Re-check custom module wiring after any upstream UI changes in battle modules.
