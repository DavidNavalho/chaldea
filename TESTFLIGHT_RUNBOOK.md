# Chaldea Personal Fork: iOS and TestFlight Runbook

Last updated: 2026-08-20

This document is the complete handoff for building, signing, uploading, and
installing this personal Chaldea fork through TestFlight. It is intended for
both the repository owner and a future coding agent continuing the work.

## Objective

Build the personal Chaldea fork for iOS, sign it with the owner's Apple
Developer team, upload it to App Store Connect, distribute it through
TestFlight, and install it on the owner's iOS devices.

The fork must remain close to upstream. Personal identity and distribution
changes should stay isolated, with the smallest practical edits to
upstream-owned files.

## Repository and Worktree

- Repository worktree:
  `/Users/jinx/gits/personal/chaldea/.dev/worktree/sharp-ocean`
- Branch: `sharp-ocean`
- Canonical cross-computer handoff: `HANDOFF.md`
- The iOS fork changes are intentionally isolated on this branch.
- Do not reset, discard, or overwrite unrelated working-tree changes.
- Do not commit credentials, provisioning profiles, certificates, private
  keys, App Store Connect API keys, or Apple account information.

Before continuing, run:

```sh
cd /Users/jinx/gits/personal/chaldea/.dev/worktree/sharp-ocean
git status --short
sed -n '1,260p' HANDOFF.md
```

## Personal Apple Identity

These values are deliberate and should remain consistent across Xcode, the
Apple Developer portal, App Store Connect, entitlements, and application code.

| Item | Value |
| --- | --- |
| Apple Developer Team ID | `WAF9PC2Y8K` |
| Main app bundle ID | `io.github.davidnavalho.chaldea` |
| Widget bundle ID | `io.github.davidnavalho.chaldea.FakerStatusWidget` |
| Shared App Group | `group.io.github.davidnavalho.chaldea.shared` |
| Installed app display name | `Chaldea` |
| Current app version | `2.5.27` |
| Current TestFlight build | `990` (build override; `pubspec.yaml` remains `+989`) |
| Main app minimum iOS | `15.0` |
| Widget minimum iOS | `18.1` |

The widget is embedded in the main app. It needs its own App ID and
provisioning profile but does not get a separate App Store Connect app record.

## Universal Links

The fork does not claim the upstream project's universal-link domain.
Associated Domains were intentionally removed from the active fork
entitlements because the owner does not control the upstream domain.

The upstream entitlement files and web association file remain in the
repository but are inactive for this fork. Do not enable Associated Domains or
register the upstream universal-link path unless the owner later controls an
appropriate domain and deliberately implements that feature.

Ordinary HTTP/HTTPS links and custom URL handling are separate from the
Associated Domains entitlement. Removing the upstream claim avoids invalid or
misleading domain ownership without requiring a broad application refactor.

## Fork Isolation Design

The primary identity values live in:

`ios/Flutter/ForkIdentity.xcconfig`

That file defines the Team ID, bundle IDs, App Group, and iOS deployment floor.

Fork-only entitlement files:

- `ios/Chaldea/Fork.entitlements`
- `ios/FakerStatusWidgetExtension.fork.entitlements`

Both active entitlement files contain only the personal App Group. They do not
claim the upstream universal-link domain.

Fork-only App Group constants:

- Dart: `lib/custom/ios/fork_identity.dart`
- Swift: `ios/FakerStatusWidget/ForkIdentity.swift`

Thin adapters in upstream-owned files:

- `lib/packages/home_widget.dart` reads the Dart fork App Group constant.
- `ios/FakerStatusWidget/FakerStatusWidget.swift` reads the Swift fork App
  Group constant.
- `ios/Chaldea.xcodeproj/project.pbxproj` points targets to fork variables and
  entitlements, applies the iOS 15 variable, and synchronizes widget versions.
- `ios/Podfile` forces all generated Pod project and target deployment settings
  to iOS 15 after Flutter applies its settings. Xcode 27 rejects the older Pod
  deployment defaults.
- `ios/Chaldea/Chaldea-Bridging-Header.h` and the Xcode project point to
  Flutter 3.41's generated registrant under `ios/Runner`. The native app source
  folder is named `Chaldea`, but current Flutter always generates the files in
  its standard `Runner` folder.

Do not commit generated files from `ios/Runner`, `ios/Pods`, `build`, or Xcode
DerivedData.

## Toolchain State

Installed and validated on this machine:

- Homebrew FVM: `4.1.2`
- Flutter through FVM: `3.41.7`
- Dart: `3.11.5`
- CocoaPods: `1.16.2`
- Xcode: `27.0 beta 5`, build `27A5237l`
- Active developer directory:
  `/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer`
- Active iOS SDK: iOS `27.0` beta

The repository `.fvmrc` was aligned with `pubspec.yaml` and now selects Flutter
3.41.7.

Verify the environment with:

```sh
xcode-select -p
xcodebuild -version
fvm --version
fvm flutter --version
fvm flutter doctor -v
pod --version
```

Expected Xcode selection:

```text
/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer
```

Do not install another Xcode or OS version without the owner's explicit
approval. Xcode 27 beta 1 was rejected by App Store Connect as unsupported;
beta 5 was accepted for builds `2.5.27 (989)` and `2.5.27 (990)` on
2026-08-20.

Official App Store Connect release notes:

https://developer.apple.com/help/app-store-connect/release-notes/

## Completed Dependency Setup

These commands already succeeded:

```sh
fvm flutter pub get
fvm flutter precache --ios
cd ios
pod install
cd ..
```

CocoaPods currently resolves 27 dependencies and 29 total Pods.

If dependencies are regenerated, confirm every generated Pod deployment target
is iOS 15:

```sh
rg -o 'IPHONEOS_DEPLOYMENT_TARGET = [^;]+' \
  ios/Pods/Pods.xcodeproj/project.pbxproj | sort -u
```

Expected output:

```text
IPHONEOS_DEPLOYMENT_TARGET = 15.0
```

## Completed Build and TestFlight Validation

The following command succeeds with Xcode 27 beta 5:

```sh
fvm flutter build ipa --release --no-codesign
```

Successful archive:

`build/ios/archive/Chaldea.xcarchive`

Last validated artifact metadata:

```text
Main app:
  Version: 2.5.27
  Build: 990
  Bundle: io.github.davidnavalho.chaldea
  Minimum iOS: 15.0

Widget extension:
  Version: 2.5.27
  Build: 990
  Bundle: io.github.davidnavalho.chaldea.FakerStatusWidget
  Minimum iOS: 18.1
```

The archive is a generated, ignored artifact and may not exist on another
machine. Rebuild it with the command above if needed.

The signed archive command also succeeds:

```sh
fvm flutter build ipa --release --export-method app-store
```

The command-line archive succeeds, but its IPA export may report `No Accounts`
or a missing `iOS Distribution` certificate. Xcode Organizer's recommended App
Store Connect distribution flow successfully resolved cloud-managed signing,
uploaded the build, and was accepted by Apple. Xcode reported a non-blocking
missing dSYM warning for `objective_c.framework`; the upload still completed.

Current App Store Connect/TestFlight state:

- App: `Chaldea Personal` (numeric app ID `6801619927`)
- Uploaded build: `2.5.27 (990)`
- Build state: processed and `Ready to Submit`
- Internal group: `Chaldea Internal`
- Automatic distribution: enabled
- Builds in group: 2 (`989` and `990`)
- Internal tester: owner's App Store Connect account
- On-device result: build 990 installs from TestFlight and NA Account File login succeeds

Future uploaded Xcode builds are automatically distributed to the internal
group.

### NA Account Login Fix in Build 990

Build `989` exposed a pre-existing upstream NA account-login bug: it combined
the NA app version with JP game data metadata, causing FGO response code `89`
with action `data_update`. Build `990` contains the exact upstream fix from
commit `b3a096eb8` (`Fix wrong game top caused login failure`).

The patch is intentionally limited to the three upstream files changed by that
commit:

- `lib/app/api/atlas.dart`
- `lib/app/modules/import_data/autologin/autologin_page.dart`
- `lib/models/faker/jp/agent.dart`

It preserves the selected region for region-info requests, uses
`tops.of(user.region)` instead of hard-coded JP metadata, and avoids retaining
a stale page-level game-top value. The local patch and upstream commit have the
same stable patch ID. Use build `990`, not `989`, for NA account login.
The owner confirmed the corrected login flow works on-device with build 990.

## Completed Apple Setup (Reference)

The following steps require the repository owner's Apple account. An agent must
not request that the owner paste a password, two-factor authentication code,
private key, or certificate into chat or commit one to the repository.

### 1. Confirm Paid Apple Developer Program Membership

Sign in at:

https://developer.apple.com/account/

Confirm that team `WAF9PC2Y8K` has an active paid Apple Developer Program
membership. A free Personal Team can install development builds directly on
registered devices, but it cannot publish through App Store Connect or
TestFlight.

Accept any pending Apple Developer agreements. Also check the Business section
in App Store Connect for pending agreements. Apple will not allow a new app
record until required agreements are accepted.

### 2. Add the Apple Account to Xcode 27 Beta

Open `/Applications/Xcode-27.0.0-Beta.5.app`, then use:

```text
Xcode -> Settings -> Accounts -> + -> Apple Account
```

Sign in locally and complete two-factor authentication. Confirm that team
`WAF9PC2Y8K` appears for the account.

If available, open Manage Certificates and confirm that Xcode can manage Apple
Development and Apple Distribution certificates. Do not manually revoke the
existing certificates. Automatic signing can create or download what is
needed later.

### 3. Register the Shared App Group

Open Certificates, Identifiers & Profiles:

https://developer.apple.com/account/resources/identifiers/list

Create this identifier first:

```text
Type: App Groups
Description: Chaldea Shared Data
Identifier: group.io.github.davidnavalho.chaldea.shared
```

Official instructions:

https://developer.apple.com/help/account/identifiers/register-an-app-group/

### 4. Register the Main App ID

Create an explicit App ID:

```text
Type: App IDs -> App
Description: Chaldea Personal
Bundle ID type: Explicit
Bundle ID: io.github.davidnavalho.chaldea
Capability: App Groups
Assigned group: group.io.github.davidnavalho.chaldea.shared
```

Do not enable Associated Domains for this fork.

### 5. Register the Widget App ID

Create a second explicit App ID:

```text
Type: App IDs -> App
Description: Chaldea Faker Status Widget
Bundle ID type: Explicit
Bundle ID: io.github.davidnavalho.chaldea.FakerStatusWidget
Capability: App Groups
Assigned group: group.io.github.davidnavalho.chaldea.shared
```

The bundle ID is case-sensitive. Use `FakerStatusWidget` exactly as shown.

Official App ID and capability instructions:

- https://developer.apple.com/help/account/identifiers/register-an-app-id
- https://developer.apple.com/help/account/identifiers/enable-app-capabilities/

### 6. Create the App Store Connect App Record

Sign in at:

https://appstoreconnect.apple.com/

Open Apps, select the add button, then select New App. Enter:

```text
Platform: iOS
Name: any available name chosen by the owner
Primary language: owner's preference
Bundle ID: io.github.davidnavalho.chaldea
SKU: chaldea-personal-ios
User access: Full Access
```

The App Store Connect name may differ from the installed display name. The app
will still display as `Chaldea` on the device unless the repository's Info
configuration is deliberately changed.

Do not create a separate record for the widget extension.

If `Chaldea` is unavailable as an App Store Connect name, choose another name
such as `Chaldea Personal`. The SKU is private internal metadata but cannot be
reused after the record is created.

Official instructions:

https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/

## Agent Continuation Checklist

Once the user confirms all Apple setup steps are complete, the next agent
should proceed as follows.

### 1. Preserve and Inspect Current Work

```sh
cd /Users/jinx/gits/personal/chaldea/.dev/worktree/sharp-ocean
git status --short
git diff --check
sed -n '1,320p' HANDOFF.md
sed -n '1,420p' TESTFLIGHT_RUNBOOK.md
```

Do not use `git reset --hard`, `git checkout --`, or another destructive command
on this worktree.

### 2. Confirm Xcode Account and Team Resolution

```sh
security find-identity -v -p codesigning
xcodebuild -workspace ios/Chaldea.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -showBuildSettings | \
  rg '^\s*(CODE_SIGN_ENTITLEMENTS|CODE_SIGN_IDENTITY|CODE_SIGN_STYLE|DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|PROVISIONING_PROFILE_SPECIFIER)\s*='
```

Expected core values:

```text
CODE_SIGN_ENTITLEMENTS = Chaldea/Fork.entitlements
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = WAF9PC2Y8K
PRODUCT_BUNDLE_IDENTIFIER = io.github.davidnavalho.chaldea
```

Also verify the widget:

```sh
xcodebuild -workspace ios/Chaldea.xcworkspace \
  -scheme FakerStatusWidgetExtension \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -showBuildSettings | \
  rg '^\s*(CODE_SIGN_ENTITLEMENTS|DEVELOPMENT_TEAM|IPHONEOS_DEPLOYMENT_TARGET|PRODUCT_BUNDLE_IDENTIFIER|CURRENT_PROJECT_VERSION|MARKETING_VERSION)\s*='
```

### 3. Refresh Dependencies Without Changing Versions

```sh
fvm flutter pub get
fvm flutter precache --ios
cd ios
pod install
cd ..
```

Do not run broad dependency upgrades merely to produce the TestFlight build.

### 4. Trigger Automatic Signing

First try:

```sh
fvm flutter build ipa --release --export-method app-store
```

With Xcode signed in and both identifiers registered, automatic signing should
create or download the necessary profiles for the main app and widget.

If Flutter still reports missing profiles:

1. Open `ios/Chaldea.xcworkspace` in Xcode.
2. Select the `Chaldea` target.
3. Open Signing & Capabilities.
4. Confirm Automatically manage signing is enabled.
5. Select team `WAF9PC2Y8K`.
6. Repeat for `FakerStatusWidgetExtension`.
7. Confirm both targets show the intended bundle IDs and App Group.
8. Let Xcode resolve signing, then retry the Flutter build.

The workspace is `Chaldea.xcworkspace`; Flutter's generic error may incorrectly
suggest opening `Runner.xcworkspace`, which does not exist here.

If command-line provisioning requires explicit permission, archive/export with
Xcode using `-allowProvisioningUpdates`, or use Xcode Organizer. Do not create
or commit manual provisioning-profile files unless automatic signing genuinely
cannot resolve the setup.

### 5. Build-Number Rules

Every uploaded build for the same app version needs a unique, increasing build
number. The current repository version is:

```text
2.5.27+989
```

Builds `989` and `990` were accepted by App Store Connect on 2026-08-20 and
must not be reused for another upload. For the next upload, either update the
version in `pubspec.yaml` or build with an override:

```sh
fvm flutter build ipa \
  --release \
  --export-method app-store \
  --build-name 2.5.27 \
  --build-number 991
```

Do not increase the build number merely because a local build failed before
upload. Increase it after App Store Connect has accepted that build number.

### 6. Validate the Signed Artifact

Flutter should produce:

- Archive: `build/ios/archive/Chaldea.xcarchive`
- IPA directory: `build/ios/ipa/`

Inspect the archive metadata:

```sh
archive_path='build/ios/archive/Chaldea.xcarchive'
app_path="$archive_path/Products/Applications/Chaldea.app"
widget_path="$app_path/PlugIns/FakerStatusWidgetExtension.appex"

/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$app_path/Info.plist"

/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$widget_path/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$widget_path/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$widget_path/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$widget_path/Info.plist"
```

The app and widget version/build values must match.

Inspect signatures and resolved entitlements:

```sh
codesign --verify --deep --strict --verbose=2 "$app_path"
codesign -d --entitlements :- "$app_path"
codesign -d --entitlements :- "$widget_path"
```

Expected App Group in both signed bundles:

```text
group.io.github.davidnavalho.chaldea.shared
```

Confirm no upstream App Group or associated-domain entitlement remains active.

### 7. Upload to App Store Connect

Preferred interactive route:

1. Open `build/ios/archive/Chaldea.xcarchive` in Xcode Organizer.
2. Select Distribute App.
3. Select App Store Connect.
4. Select Upload.
5. Use automatic signing if prompted.
6. Review Xcode's validation report.
7. Upload.

An agent may use a command-line upload only when the user has deliberately
provided a secure credential mechanism. Never put an App Store Connect API
private key or app-specific password in this repository, command output, or
chat transcript.

Apple supports uploads through Xcode, Transporter, and App Store Connect API
credentials:

https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/

If App Store Connect rejects the installed Xcode 27 beta build because it is an
older beta, update Xcode 27 beta or install the currently accepted stable Xcode.
Do not change the iOS deployment target solely to solve an upload-tool version
rejection.

### 8. Wait for Build Processing

After upload, App Store Connect processes the build. It may initially show as
Processing and later become available under the TestFlight tab. Check the
delivery log or email if processing fails.

The app's release plist currently declares:

```text
ITSAppUsesNonExemptEncryption = false
```

This should normally avoid repeated export-compliance questions for a build
that does not add non-exempt encryption. Answer App Store Connect questions
truthfully if Apple still requests confirmation.

### 9. Configure Internal TestFlight Testing

Internal testing is the quickest route for the owner's devices:

1. Open the app in App Store Connect.
2. Open TestFlight.
3. Create an Internal Testing group if none exists.
4. Add the processed build to the group.
5. Add the owner's App Store Connect user as an internal tester.
6. Install Apple's TestFlight app on each iOS device.
7. Accept the invitation using the matching Apple account.
8. Install Chaldea from TestFlight.

Internal testers must be App Store Connect users. For a tester who should not
be an App Store Connect user, use external testing instead.

Official TestFlight overview:

https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview

### 10. Configure External Testing if Needed

External testing is optional for the owner's immediate goal. It requires:

- TestFlight beta description
- Feedback email
- Test information
- An external testing group
- Adding the build to that group
- Beta App Review for the first external build, with later builds sometimes
  accepted without another full review

Do not start external distribution unless the owner asks for it.

## Validation and Known Test State

Static checks that pass:

```sh
plutil -lint \
  ios/Chaldea.xcodeproj/project.pbxproj \
  ios/Chaldea/Fork.entitlements \
  ios/FakerStatusWidgetExtension.fork.entitlements

ruby -c ios/Podfile
git diff --check
```

`fvm flutter analyze` previously completed with 15 pre-existing informational
lints. There were no findings in the fork identity files.

The test command must include the repository path:

```sh
fvm flutter test \
  --dart-define=APP_PATH=/Users/jinx/gits/personal/chaldea/.dev/worktree/sharp-ocean
```

Current result:

- 14 tests pass, including the custom box-coverage tests.
- Six data-dependent suites fail during initialization because the worktree has
  no offline game-data payload (`No data found`, data version `null`).
- Those failures are not caused by the iOS identity, deployment, or signing
  changes.

Do not alter application logic merely to hide the missing test-data condition.
If full test validation is required, obtain or generate the expected offline
game-data payload through the repository's normal data workflow first.

## Troubleshooting Matrix

### `No Accounts`

Cause: Xcode has no signed-in Apple account.

Resolution: Xcode -> Settings -> Accounts, sign in, and confirm team
`WAF9PC2Y8K`.

### `No profiles for ... were found`

Cause: App IDs/capabilities are not registered, the account is not available to
Xcode, or automatic signing has not generated profiles.

Resolution: Verify both explicit App IDs, assign the App Group to both, select
the team in Signing & Capabilities, and rebuild.

### App Group entitlement mismatch

Cause: The portal assignment and the local entitlement do not match.

Resolution: Both identifiers and both signed bundles must use exactly:

`group.io.github.davidnavalho.chaldea.shared`

### Deployment-target error under Xcode 27

Cause: The app or a generated Pod resolved below iOS 15.

Resolution: Confirm `CHALDEA_IOS_DEPLOYMENT_TARGET = 15.0` in
`ForkIdentity.xcconfig`, rerun `pod install`, and verify that the generated Pods
project contains only iOS 15 deployment values. Do not edit the generated Pods
project directly.

### `GeneratedPluginRegistrant.h` not found

Cause: Current Flutter generates the registrant in `ios/Runner`, while the
native source folder is `ios/Chaldea`.

Resolution: Preserve the current thin project/bridging-header adapter pointing
to `../Runner/GeneratedPluginRegistrant.*`; run `fvm flutter pub get` before
building. Do not commit the generated files.

### Widget and containing-app version mismatch

Cause: Widget target version settings were reset to hard-coded `1.0 (1)`.

Resolution: Preserve the widget target settings based on
`FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER`, then rebuild and inspect both
Info.plists.

### App Store Connect does not list the bundle ID

Cause: The explicit App ID was not registered under the same paid team, a
required agreement is pending, or App Store Connect has not refreshed.

Resolution: Confirm team `WAF9PC2Y8K`, accept agreements, verify the main App
ID, then sign out/in or wait briefly before creating the app record.

### Xcode 27 beta upload rejection

Cause: App Store Connect may have stopped accepting the installed early beta.

Resolution: Update to a currently supported Xcode 27 beta or install the
current stable Xcode. Keep the app minimum at iOS 15 unless device support
requirements change.

## Completion Criteria

The TestFlight objective is complete only when all of the following are true:

- Paid Apple Developer membership is active.
- Xcode is signed in to team `WAF9PC2Y8K`.
- The App Group is registered.
- Both explicit App IDs are registered and assigned to the App Group.
- The main App Store Connect record exists.
- A signed archive and IPA build successfully.
- Main app and widget signatures contain the personal App Group.
- App Store Connect accepts and processes the uploaded build.
- The build is assigned to an internal TestFlight group.
- The owner can install and launch Chaldea from TestFlight on the intended iOS
  devices.
- Shared App Group functionality is checked on a device where the widget is
  available.
- `HANDOFF.md` is updated with the final result and any remaining caveats.

## Relevant Official Apple Documentation

- Register an App Group:
  https://developer.apple.com/help/account/identifiers/register-an-app-group/
- Register an App ID:
  https://developer.apple.com/help/account/identifiers/register-an-app-id
- Enable App Groups:
  https://developer.apple.com/help/account/identifiers/enable-app-capabilities/
- Create an App Store Connect app record:
  https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- Upload builds:
  https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- TestFlight overview:
  https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
- App Store Connect release notes and Xcode beta support:
  https://developer.apple.com/help/app-store-connect/release-notes/
