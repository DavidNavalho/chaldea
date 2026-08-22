#!/bin/bash
set -euo pipefail

log() {
  printf '[xcode-cloud] %s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

assert_contains() {
  local settings="$1"
  local expected="$2"
  grep -Fq "$expected" <<<"$settings" || fail "Resolved build settings are missing: $expected"
}

assert_excludes() {
  local settings="$1"
  local forbidden="$2"
  if grep -Fq "$forbidden" <<<"$settings"; then
    fail "Resolved build settings still contain upstream identity: $forbidden"
  fi
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${CI_PRIMARY_REPOSITORY_PATH:-$(git -C "$script_dir" rev-parse --show-toplevel)}"
cd "$repo_root"

expected_xcconfig="$repo_root/ios/Flutter/ForkIdentity.xcconfig"
[[ -n "${XCODE_XCCONFIG_FILE:-}" ]] || fail 'XCODE_XCCONFIG_FILE is not set.'
[[ -f "$XCODE_XCCONFIG_FILE" ]] || fail "XCODE_XCCONFIG_FILE does not exist: $XCODE_XCCONFIG_FILE"
resolved_xcconfig="$(/usr/bin/ruby -e 'print File.realpath(ARGV.fetch(0))' "$XCODE_XCCONFIG_FILE")"
resolved_expected_xcconfig="$(/usr/bin/ruby -e 'print File.realpath(ARGV.fetch(0))' "$expected_xcconfig")"
[[ "$resolved_xcconfig" == "$resolved_expected_xcconfig" ]] || {
  fail "XCODE_XCCONFIG_FILE must resolve to $expected_xcconfig, found $resolved_xcconfig."
}

[[ -f ios/Flutter/Generated.xcconfig ]] || fail 'Flutter generated configuration is missing.'
[[ -f ios/Flutter/ephemeral/ForkIdentityDependencies.xcconfig ]] || fail 'Fork dependency-target map is missing.'

log 'Resolving main-app build settings through the external identity overlay.'
app_settings="$(
  xcodebuild \
    -workspace ios/Chaldea.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -showBuildSettings
)"

assert_contains "$app_settings" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.davidnavalho.chaldea'
assert_contains "$app_settings" 'DEVELOPMENT_TEAM = WAF9PC2Y8K'
assert_contains "$app_settings" 'CODE_SIGN_ENTITLEMENTS = Chaldea/Fork.entitlements'
assert_contains "$app_settings" 'IPHONEOS_DEPLOYMENT_TARGET = 15.0'
assert_excludes "$app_settings" 'PRODUCT_BUNDLE_IDENTIFIER = cc.narumi.chaldea'
assert_excludes "$app_settings" 'DEVELOPMENT_TEAM = 4Z25Q4L3F2'
assert_excludes "$app_settings" 'CODE_SIGN_ENTITLEMENTS = Chaldea/Chaldea.entitlements'

log 'Resolving widget build settings through the external identity overlay.'
widget_settings="$(
  xcodebuild \
    -workspace ios/Chaldea.xcworkspace \
    -scheme FakerStatusWidgetExtension \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -showBuildSettings
)"

assert_contains "$widget_settings" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.davidnavalho.chaldea.FakerStatusWidget'
assert_contains "$widget_settings" 'DEVELOPMENT_TEAM = WAF9PC2Y8K'
assert_contains "$widget_settings" 'CODE_SIGN_ENTITLEMENTS = FakerStatusWidgetExtension.fork.entitlements'
assert_contains "$widget_settings" 'IPHONEOS_DEPLOYMENT_TARGET = 18.1'
assert_excludes "$widget_settings" 'PRODUCT_BUNDLE_IDENTIFIER = cc.narumi.chaldea.FakerStatusWidget'
assert_excludes "$widget_settings" 'DEVELOPMENT_TEAM = 4Z25Q4L3F2'
assert_excludes "$widget_settings" 'CODE_SIGN_ENTITLEMENTS = FakerStatusWidgetExtension.entitlements'

log 'Fork identity is ready for the Xcode Cloud build.'
