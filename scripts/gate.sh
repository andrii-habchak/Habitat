#!/usr/bin/env bash
# Local quality gate (DECISIONS D8: no hosted CI).
#
#   scripts/gate.sh fast   lint, package tests, app + UI-test build for the simulator
#   scripts/gate.sh full   fast + XCUITests on the Habitat-QA simulator (QA agents only)
#
# All build output goes to build.noindex/ (git-ignored). Warnings are errors everywhere:
# swiftlint --strict, `.treatAllWarnings(as: .error)` in HabitatKit, and
# SWIFT_TREAT_WARNINGS_AS_ERRORS in project.yml (also forced on the command line below).
#
# full mode reads the simulator UDID from .run/sim-udid of the main checkout (worktrees
# share it). Override with HABITAT_SIM_UDID=<udid>.
set -euo pipefail

mode="${1:-fast}"
case "$mode" in
  fast|full) ;;
  *) echo "usage: $0 fast|full" >&2; exit 64 ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
build="$root/build.noindex"
logs="$build/logs"
derived="$build/DerivedData"
mkdir -p "$logs"

step() { printf '\n==> %s\n' "$*"; }

# Runs a command with its output in a log file; prints the tail and fails on error.
run_logged() {
  local name="$1"; shift
  local log="$logs/$name.log"
  if ! "$@" >"$log" 2>&1; then
    echo "FAILED: $name (full log: $log)" >&2
    grep -E "error:|warning:|failed|FAILED|✘" "$log" | head -60 >&2 || true
    tail -30 "$log" >&2
    exit 1
  fi
  echo "ok: $name"
}

xcodebuild_common=(
  -project Habitat.xcodeproj
  -scheme Habitat
  -configuration Debug
  -derivedDataPath "$derived"
  -clonedSourcePackagesDirPath "$build/SourcePackages"
  -packageCachePath "$build/PackageCache"
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
)

step "swiftlint --strict"
run_logged swiftlint swiftlint lint --strict --quiet --cache-path "$build/swiftlint-cache"

step "swift test (HabitatKit)"
run_logged swift-test swift test --package-path HabitatKit --scratch-path "$build/spm"

step "xcodegen"
run_logged xcodegen xcodegen generate --spec project.yml --quiet

step "xcodebuild build-for-testing (generic iOS Simulator)"
run_logged xcodebuild-build xcodebuild build-for-testing "${xcodebuild_common[@]}" \
  -destination 'generic/platform=iOS Simulator'

if [ "$mode" = full ]; then
  udid="${HABITAT_SIM_UDID:-}"
  if [ -z "$udid" ]; then
    main_checkout="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
    udid_file="$main_checkout/.run/sim-udid"
    if [ ! -f "$udid_file" ]; then
      echo "no simulator UDID: $udid_file is missing (run scripts/kickoff.sh)" >&2
      exit 1
    fi
    udid="$(tr -d '[:space:]' <"$udid_file")"
  fi
  mkdir -p "$build/results"
  step "xcodebuild test (XCUITests on $udid)"
  run_logged xcodebuild-test xcodebuild test "${xcodebuild_common[@]}" \
    -destination "id=$udid" \
    -resultBundlePath "$build/results/ui-$(date +%Y%m%d-%H%M%S).xcresult"
fi

printf '\nGATE %s: PASS\n' "$mode"
