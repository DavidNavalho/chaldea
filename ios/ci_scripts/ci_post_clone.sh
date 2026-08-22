#!/bin/bash
set -euo pipefail

log() {
  printf '[xcode-cloud] %s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

flutter_framework_version() {
  local flutter_executable="$1"

  "$flutter_executable" --version --machine | /usr/bin/ruby -rjson -e '
    output = STDIN.read
    json_start = output.index("{")
    raise JSON::ParserError, "Flutter did not emit machine-readable version JSON" unless json_start
    print JSON.parse(output[json_start..-1]).fetch("frameworkVersion")
  '
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${CI_PRIMARY_REPOSITORY_PATH:-$(git -C "$script_dir" rev-parse --show-toplevel)}"
cd "$repo_root"

[[ -f .fvmrc ]] || fail 'Missing .fvmrc.'
[[ -f pubspec.yaml ]] || fail 'Missing pubspec.yaml.'

flutter_version="$(/usr/bin/ruby -rjson -e 'print JSON.parse(File.read(ARGV.fetch(0))).fetch("flutter")' .fvmrc)"
[[ "$flutter_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Invalid Flutter version: $flutter_version"

flutter_bin=''
if [[ -x .fvm/flutter_sdk/bin/flutter ]]; then
  flutter_bin="$repo_root/.fvm/flutter_sdk/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  candidate_flutter="$(command -v flutter)"
  candidate_version="$(flutter_framework_version "$candidate_flutter")"
  if [[ "$candidate_version" == "$flutter_version" ]]; then
    flutter_bin="$candidate_flutter"
  fi
fi

if [[ -z "$flutter_bin" ]]; then
  flutter_root="${CI_WORKSPACE:-${HOME}}/flutter-${flutter_version}"
  if [[ ! -x "$flutter_root/bin/flutter" ]]; then
    log "Installing Flutter $flutter_version into the temporary build environment."
    git clone --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$flutter_root"
  fi
  flutter_bin="$flutter_root/bin/flutter"
fi

resolved_flutter_version="$(flutter_framework_version "$flutter_bin")"
[[ "$resolved_flutter_version" == "$flutter_version" ]] || {
  fail "Expected Flutter $flutter_version, found $resolved_flutter_version at $flutter_bin."
}

pubspec_version="$(awk '/^version:/{print $2; exit}' pubspec.yaml)"
[[ "$pubspec_version" == *+* ]] || fail 'Could not read version and build number from pubspec.yaml.'
build_name="${pubspec_version%%+*}"
build_number="${CI_BUILD_NUMBER:-${pubspec_version##*+}}"
[[ "$build_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Invalid build name: $build_name"
[[ "$build_number" =~ ^[0-9]+$ ]] || fail "Invalid build number: $build_number"

if [[ "${CI_XCODE_CLOUD:-}" == 'TRUE' ]]; then
  minimum_build_number="${CHALDEA_XCODE_CLOUD_MIN_BUILD_NUMBER:-991}"
  [[ "$minimum_build_number" =~ ^[0-9]+$ ]] || fail 'CHALDEA_XCODE_CLOUD_MIN_BUILD_NUMBER must be numeric.'
  (( build_number >= minimum_build_number )) || {
    fail "Xcode Cloud build number $build_number is below the required minimum $minimum_build_number."
  }

  expected_xcconfig="$repo_root/ios/Flutter/ForkIdentity.xcconfig"
  [[ -n "${XCODE_XCCONFIG_FILE:-}" ]] || fail 'Set XCODE_XCCONFIG_FILE in the Xcode Cloud workflow.'
  [[ -f "$XCODE_XCCONFIG_FILE" ]] || fail "XCODE_XCCONFIG_FILE does not exist: $XCODE_XCCONFIG_FILE"
  resolved_xcconfig="$(/usr/bin/ruby -e 'print File.realpath(ARGV.fetch(0))' "$XCODE_XCCONFIG_FILE")"
  resolved_expected_xcconfig="$(/usr/bin/ruby -e 'print File.realpath(ARGV.fetch(0))' "$expected_xcconfig")"
  [[ "$resolved_xcconfig" == "$resolved_expected_xcconfig" ]] || {
    fail "XCODE_XCCONFIG_FILE must resolve to $expected_xcconfig, found $resolved_xcconfig."
  }
fi

log "Preparing Flutter $flutter_version for Chaldea $build_name ($build_number)."
"$flutter_bin" config --no-analytics
"$flutter_bin" precache --ios
"$flutter_bin" pub get
"$flutter_bin" build ios \
  --release \
  --config-only \
  --no-codesign \
  "--build-name=$build_name" \
  "--build-number=$build_number" \
  --dart-define=CHALDEA_IOS_APP_GROUP_ID=group.io.github.davidnavalho.chaldea.shared

if ! command -v pod >/dev/null 2>&1; then
  command -v brew >/dev/null 2>&1 || fail 'CocoaPods is missing and Homebrew is unavailable.'
  log 'Installing CocoaPods into the temporary build environment.'
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

log 'Resolving CocoaPods dependencies from the committed lockfile.'
(
  cd ios
  pod install
)

log 'Applying the fork deployment compatibility map to generated dependencies.'
/usr/bin/ruby scripts/fork/prepare_ios_testflight.rb

if ! git diff --quiet -- .; then
  git diff --stat -- . >&2
  fail 'Cloud preparation changed tracked files. Commit intentional changes before building.'
fi

grep -Fq "FLUTTER_BUILD_NAME=$build_name" ios/Flutter/Generated.xcconfig || fail 'Generated build name is incorrect.'
grep -Fq "FLUTTER_BUILD_NUMBER=$build_number" ios/Flutter/Generated.xcconfig || fail 'Generated build number is incorrect.'

log 'Cloud preparation complete.'
