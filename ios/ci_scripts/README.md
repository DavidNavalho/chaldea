# Xcode Cloud TestFlight Workflow

These fork-only scripts prepare and validate Chaldea's personal iOS identity in
Xcode Cloud. They leave the upstream Xcode project and GitHub Actions workflows
unchanged.

The active App Store Connect workflow is `Manual TestFlight Delivery`
(`cae29f8a-2bfa-4830-beec-bb88072853c9`). It is configured with:

- Product: Chaldea Personal (`io.github.davidnavalho.chaldea`)
- Repository: `DavidNavalho/chaldea`
- Branch: any branch, so a reviewed branch can be validated before merging
- Start condition: manual
- Action: archive the shared `Runner` scheme for iOS using Release
- Post-action: distribute to the internal TestFlight group `Chaldea Internal`
- Xcode: Latest Beta or Release
- macOS: Latest Release
- Environment variables:
  - `XCODE_XCCONFIG_FILE=/Volumes/workspace/repository/ios/Flutter/ForkIdentity.xcconfig`
  - `CHALDEA_XCODE_CLOUD_MIN_BUILD_NUMBER=1`

The Xcode Cloud repository path above is Apple's documented default. The
post-clone script resolves and verifies it against `CI_PRIMARY_REPOSITORY_PATH`
and fails before building if Apple supplies a different location.

The workflow requires no App Store Connect API key in the repository. Xcode
Cloud manages signing, upload, processing, and internal TestFlight distribution.

Xcode Cloud build numbers start from its own sequence. App Store Connect accepts
an iOS build when the marketing-version/build-number pair is unique, so Cloud
build `2.6.0 (5)` does not conflict with the earlier manually uploaded
`2.5.27 (990)`. The second environment variable deliberately relaxes the
script's conservative default minimum of `991` for this workflow.

The scripts perform the following checks before Apple receives a build:

1. Install the exact Flutter version declared by `.fvmrc` in the temporary
   build environment.
2. Generate Flutter iOS configuration with Xcode Cloud's build number.
3. Resolve CocoaPods and prepare generated dependency deployment targets.
4. Verify that the main app and widget resolve only the personal Team ID,
   bundle IDs, entitlements, and deployment targets.
5. Validate the signed archive, including App Groups, before distribution.

The first complete delivery was Xcode Cloud build `5` on 2026-08-22 using Xcode
27 beta 5 and macOS Tahoe 26.6.2. The archive and internal TestFlight post-action
both succeeded; App Store Connect processed `2.6.0 (5)` and assigned it to
`Chaldea Internal` in Testing status.

An earlier bootstrap workflow named `Manual TestFlight`
(`08697A88-8BA0-452D-87DD-923F8A0645B3`) is deactivated. Leave it deactivated
so only the clean delivery workflow can start builds.

Keep manual triggering unless every merge should produce a TestFlight build.
If automatic delivery is later desired, restrict the branch-change trigger to
`main` after the automation PR has merged.
