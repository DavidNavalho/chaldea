#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/fork/build_ios_testflight.sh [options]

Options:
  --build-name VERSION       Defaults to pubspec.yaml.
  --build-number NUMBER      Defaults to pubspec.yaml.
  --codesign                 Create a signed archive.
  --allow-provisioning-updates
                             Allow Xcode to update signing assets; requires --codesign.
  -h, --help                 Show this help.

Environment:
  IOS_ARCHIVE_PATH           Optional archive output path.

The default validation build does not code sign. The archive is written to
build/ios/archive/Chaldea.xcarchive unless IOS_ARCHIVE_PATH is set.
EOF
}

log() {
  printf '%s\n' "$*" >&2
}

emit() {
  printf '%s=%s\n' "$1" "$2"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log "Missing required command: $1"
    exit 1
  }
}

build_name=''
build_number=''
codesign=0
allow_provisioning_updates=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-name)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      build_name="$2"
      shift 2
      ;;
    --build-number)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      build_number="$2"
      shift 2
      ;;
    --codesign)
      codesign=1
      shift
      ;;
    --allow-provisioning-updates)
      allow_provisioning_updates=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$allow_provisioning_updates" -eq 1 && "$codesign" -ne 1 ]]; then
  log '--allow-provisioning-updates requires --codesign.'
  exit 1
fi

require_cmd fvm
require_cmd git
require_cmd pod
require_cmd ruby
require_cmd xcodebuild

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

pubspec_version="$(awk '/^version:/{print $2; exit}' pubspec.yaml)"
if [[ -z "$pubspec_version" || "$pubspec_version" != *+* ]]; then
  log 'Could not read version and build number from pubspec.yaml.'
  exit 1
fi

[[ -n "$build_name" ]] || build_name="${pubspec_version%%+*}"
[[ -n "$build_number" ]] || build_number="${pubspec_version##*+}"

if [[ ! "$build_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  log "Invalid build name: $build_name"
  exit 1
fi
if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
  log "Invalid build number: $build_number"
  exit 1
fi

archive_path="${IOS_ARCHIVE_PATH:-${repo_root}/build/ios/archive/Chaldea.xcarchive}"
fork_xcconfig="${repo_root}/ios/Flutter/ForkIdentity.xcconfig"
mkdir -p "$(dirname "$archive_path")"

log 'Resolving Flutter dependencies and generated iOS configuration.'
flutter_config_args=(
  flutter build ios
  --release
  --config-only
  "--build-name=${build_name}"
  "--build-number=${build_number}"
  '--dart-define=CHALDEA_IOS_APP_GROUP_ID=group.io.github.davidnavalho.chaldea.shared'
)
if [[ "$codesign" -ne 1 ]]; then
  flutter_config_args+=(--no-codesign)
fi
fvm "${flutter_config_args[@]}"

log 'Regenerating CocoaPods integration from the unchanged upstream Podfile.'
(
  cd ios
  pod install
)

log 'Preparing ignored CocoaPods build output for Xcode 27.'
ruby scripts/fork/prepare_ios_testflight.rb

xcodebuild_args=(
  xcodebuild
  -workspace ios/Chaldea.xcworkspace
  -scheme Runner
  -configuration Release
  -destination 'generic/platform=iOS'
  -archivePath "$archive_path"
  -xcconfig "$fork_xcconfig"
  -quiet
)
if [[ "$codesign" -ne 1 ]]; then
  xcodebuild_args+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
elif [[ "$allow_provisioning_updates" -eq 1 ]]; then
  xcodebuild_args+=(-allowProvisioningUpdates)
fi
xcodebuild_args+=(archive)

log 'Creating the fork archive with the external identity overlay.'
"${xcodebuild_args[@]}"

app_path="${archive_path}/Products/Applications/Chaldea.app"
widget_path="${app_path}/PlugIns/FakerStatusWidgetExtension.appex"
[[ -d "$app_path" ]] || { log "Missing archived app: $app_path"; exit 1; }
[[ -d "$widget_path" ]] || { log "Missing archived widget: $widget_path"; exit 1; }

plist_buddy='/usr/libexec/PlistBuddy'
app_bundle_id="$($plist_buddy -c 'Print :CFBundleIdentifier' "${app_path}/Info.plist")"
widget_bundle_id="$($plist_buddy -c 'Print :CFBundleIdentifier' "${widget_path}/Info.plist")"
app_version="$($plist_buddy -c 'Print :CFBundleShortVersionString' "${app_path}/Info.plist")"
widget_version="$($plist_buddy -c 'Print :CFBundleShortVersionString' "${widget_path}/Info.plist")"
app_build="$($plist_buddy -c 'Print :CFBundleVersion' "${app_path}/Info.plist")"
widget_build="$($plist_buddy -c 'Print :CFBundleVersion' "${widget_path}/Info.plist")"
app_minimum_ios="$($plist_buddy -c 'Print :MinimumOSVersion' "${app_path}/Info.plist")"
widget_minimum_ios="$($plist_buddy -c 'Print :MinimumOSVersion' "${widget_path}/Info.plist")"

[[ "$app_bundle_id" == 'io.github.davidnavalho.chaldea' ]] || { log "Unexpected app bundle ID: $app_bundle_id"; exit 1; }
[[ "$widget_bundle_id" == 'io.github.davidnavalho.chaldea.FakerStatusWidget' ]] || { log "Unexpected widget bundle ID: $widget_bundle_id"; exit 1; }
[[ "$app_version" == "$build_name" && "$widget_version" == "$build_name" ]] || { log 'Archived versions do not match.'; exit 1; }
[[ "$app_build" == "$build_number" && "$widget_build" == "$build_number" ]] || { log 'Archived build numbers do not match.'; exit 1; }
[[ "$app_minimum_ios" == '15.0' ]] || { log "Unexpected app minimum iOS: $app_minimum_ios"; exit 1; }
[[ "$widget_minimum_ios" == '18.1' ]] || { log "Unexpected widget minimum iOS: $widget_minimum_ios"; exit 1; }

emit status archive-created
emit archive_path "$archive_path"
emit codesigned "$codesign"
emit app_bundle_id "$app_bundle_id"
emit widget_bundle_id "$widget_bundle_id"
emit version "$app_version"
emit build_number "$app_build"
emit app_minimum_ios "$app_minimum_ios"
emit widget_minimum_ios "$widget_minimum_ios"
