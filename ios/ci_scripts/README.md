# Xcode Cloud TestFlight Workflow

These fork-only scripts prepare and validate Chaldea's personal iOS identity in
Xcode Cloud. They leave the upstream Xcode project and GitHub Actions workflows
unchanged.

Configure one Xcode Cloud workflow with:

- Product: Chaldea Personal (`io.github.davidnavalho.chaldea`)
- Repository: `DavidNavalho/chaldea`
- Branch: `main`
- Start condition: manual while validating the first build
- Action: archive the shared `Runner` scheme for iOS using Release
- Post-action: distribute to the internal TestFlight group `Chaldea Internal`
- First Xcode Cloud build number: `991`
- Environment variable:
  `XCODE_XCCONFIG_FILE=/Volumes/workspace/repository/ios/Flutter/ForkIdentity.xcconfig`

The Xcode Cloud repository path above is Apple's documented default. The
post-clone script resolves and verifies it against `CI_PRIMARY_REPOSITORY_PATH`
and fails before building if Apple supplies a different location.

The workflow requires no App Store Connect API key in the repository. Xcode
Cloud manages signing, upload, processing, and internal TestFlight distribution.

The scripts perform the following checks before Apple receives a build:

1. Install the exact Flutter version declared by `.fvmrc` in the temporary
   build environment.
2. Generate Flutter iOS configuration with Xcode Cloud's build number.
3. Resolve CocoaPods and prepare generated dependency deployment targets.
4. Verify that the main app and widget resolve only the personal Team ID,
   bundle IDs, entitlements, and deployment targets.
5. Validate the signed archive, including App Groups, before distribution.

After the first manual build succeeds, the workflow may be changed to a
`main` branch-change trigger. Keep manual triggering if every merge should not
produce a TestFlight build.
