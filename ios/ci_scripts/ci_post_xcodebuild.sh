#!/bin/bash
set -euo pipefail

log() {
  printf '[xcode-cloud] %s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

if [[ "${CI_XCODEBUILD_ACTION:-}" != 'archive' ]]; then
  log 'No archive validation is needed for this action.'
  exit 0
fi

if [[ "${CI_XCODEBUILD_EXIT_CODE:-1}" != '0' ]]; then
  log 'The archive action failed before fork artifact validation.'
  exit 0
fi

[[ -n "${CI_ARCHIVE_PATH:-}" ]] || fail 'CI_ARCHIVE_PATH is unavailable after the archive action.'

app_path="$CI_ARCHIVE_PATH/Products/Applications/Chaldea.app"
widget_path="$app_path/PlugIns/FakerStatusWidgetExtension.appex"
[[ -d "$app_path" ]] || fail "Missing archived app: $app_path"
[[ -d "$widget_path" ]] || fail "Missing archived widget: $widget_path"

plist_buddy='/usr/libexec/PlistBuddy'
app_bundle_id="$($plist_buddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
widget_bundle_id="$($plist_buddy -c 'Print :CFBundleIdentifier' "$widget_path/Info.plist")"
app_version="$($plist_buddy -c 'Print :CFBundleShortVersionString' "$app_path/Info.plist")"
widget_version="$($plist_buddy -c 'Print :CFBundleShortVersionString' "$widget_path/Info.plist")"
app_build="$($plist_buddy -c 'Print :CFBundleVersion' "$app_path/Info.plist")"
widget_build="$($plist_buddy -c 'Print :CFBundleVersion' "$widget_path/Info.plist")"
app_minimum_ios="$($plist_buddy -c 'Print :MinimumOSVersion' "$app_path/Info.plist")"
widget_minimum_ios="$($plist_buddy -c 'Print :MinimumOSVersion' "$widget_path/Info.plist")"

[[ "$app_bundle_id" == 'io.github.davidnavalho.chaldea' ]] || fail "Unexpected app bundle ID: $app_bundle_id"
[[ "$widget_bundle_id" == 'io.github.davidnavalho.chaldea.FakerStatusWidget' ]] || {
  fail "Unexpected widget bundle ID: $widget_bundle_id"
}
[[ "$app_version" == "$widget_version" ]] || fail 'App and widget marketing versions differ.'
[[ "$app_build" == "$widget_build" ]] || fail 'App and widget build numbers differ.'
[[ -z "${CI_BUILD_NUMBER:-}" || "$app_build" == "$CI_BUILD_NUMBER" ]] || {
  fail "Archived build $app_build does not match Xcode Cloud build $CI_BUILD_NUMBER."
}
[[ "$app_minimum_ios" == '15.0' ]] || fail "Unexpected app minimum iOS: $app_minimum_ios"
[[ "$widget_minimum_ios" == '18.1' ]] || fail "Unexpected widget minimum iOS: $widget_minimum_ios"

codesign --verify --deep --strict --verbose=2 "$app_path"
app_entitlements="$(codesign -d --entitlements :- "$app_path" 2>&1)"
widget_entitlements="$(codesign -d --entitlements :- "$widget_path" 2>&1)"
grep -Fq 'group.io.github.davidnavalho.chaldea.shared' <<<"$app_entitlements" || fail 'App Group is missing from the app.'
grep -Fq 'group.io.github.davidnavalho.chaldea.shared' <<<"$widget_entitlements" || fail 'App Group is missing from the widget.'

for entitlements in "$app_entitlements" "$widget_entitlements"; do
  if grep -Fq 'group.cc.narumi.chaldea' <<<"$entitlements"; then
    fail 'An upstream App Group remains in the signed archive.'
  fi
  if grep -Fq 'com.apple.developer.associated-domains' <<<"$entitlements"; then
    fail 'Associated Domains unexpectedly remain in the signed archive.'
  fi
done

log "Validated Chaldea $app_version ($app_build) for internal TestFlight distribution."
