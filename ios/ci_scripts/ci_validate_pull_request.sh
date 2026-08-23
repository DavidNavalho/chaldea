#!/bin/bash
set -euo pipefail

log() {
  printf '[xcode-cloud-pr] %s\n' "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${CI_PRIMARY_REPOSITORY_PATH:-$(git -C "$script_dir" rev-parse --show-toplevel)}"
cd "$repo_root"

flutter_bin="${CHALDEA_FLUTTER_BIN:-}"
if [[ -z "$flutter_bin" && -x .fvm/flutter_sdk/bin/flutter ]]; then
  flutter_bin="$repo_root/.fvm/flutter_sdk/bin/flutter"
fi
if [[ -z "$flutter_bin" ]]; then
  flutter_bin="$(command -v flutter || true)"
fi
[[ -n "$flutter_bin" && -x "$flutter_bin" ]] || fail 'Flutter executable is unavailable.'

cleanup_validation_root='false'
if [[ -n "${CI_WORKSPACE:-}" ]]; then
  validation_root="$CI_WORKSPACE/chaldea-pr-validation"
else
  validation_root="$(mktemp -d)"
  cleanup_validation_root='true'
fi

cleanup() {
  if [[ "$cleanup_validation_root" == 'true' ]]; then
    rm -rf "$validation_root"
  fi
}
trap cleanup EXIT

data_repo_url="${CHALDEA_VALIDATION_DATA_REPO_URL:-https://github.com/chaldea-center/chaldea-data.git}"
data_ref="${CHALDEA_VALIDATION_DATA_REF:-main}"
data_repo="$validation_root/data"
app_root="$validation_root/app"
mkdir -p "$validation_root"

if [[ ! -d "$data_repo/.git" ]]; then
  log "Cloning validation data from $data_ref."
  git clone --depth 1 --branch "$data_ref" "$data_repo_url" "$data_repo"
else
  log "Refreshing validation data from $data_ref."
  git -C "$data_repo" fetch --depth 1 origin "$data_ref"
  git -C "$data_repo" checkout --detach FETCH_HEAD
fi

[[ -d "$data_repo/dist" ]] || fail "Validation data is missing: $data_repo/dist"
mkdir -p "$app_root"
if [[ -e "$app_root/game" && ! -L "$app_root/game" ]]; then
  fail "Validation app path contains a non-symlink game directory: $app_root/game"
fi
ln -sfn "$data_repo/dist" "$app_root/game"

log 'Running Flutter static analysis.'
"$flutter_bin" analyze --no-fatal-infos --no-pub

log 'Running the Flutter test suite with offline game data.'
"$flutter_bin" test --no-pub "--dart-define=APP_PATH=$app_root"

log 'Pull-request validation passed.'
