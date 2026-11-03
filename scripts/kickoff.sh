#!/usr/bin/env bash
# Starts a run: preflight, run clock, local guard settings, QA simulator, then prints the
# orchestrator prompt (docs/NEXT.md, after the "---" line) and copies it to the clipboard.
# Start a new agent session in this folder afterwards and paste it.
#
# Usage: scripts/kickoff.sh "YYYY-MM-DD HH:MM"      deadline, Europe/Paris time
#        scripts/kickoff.sh --check                 preflight only, no run state written
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"

fail() { echo "✗ $*" >&2; exit 1; }
ok()   { echo "✓ $*"; }

check_only=false
if [ "${1:-}" = "--check" ]; then check_only=true; else
  deadline_str="${1:?usage: scripts/kickoff.sh \"YYYY-MM-DD HH:MM\" (Europe/Paris) | --check}"
fi

# 1. Toolchain
xcode-select -p | grep -q 'Xcode.app' \
  || fail "xcode-select must point at Xcode: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
ok "$(xcodebuild -version | head -1)"
for tool in xcodegen swiftlint jq caffeinate osascript; do
  command -v "$tool" >/dev/null || fail "missing tool: $tool"
done
ok "xcodegen, swiftlint, jq"
runtime="$(xcrun simctl list runtimes | grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+' | sort -V | tail -1)"
[ -n "$runtime" ] || fail "no iOS simulator runtime installed"
ok "simulator runtime $runtime"

# 2. Git identity and remote: personal identity + SSH alias, never the global/work identity
git config user.name  "andrii-habchak"
git config user.email "andrey.gabchak@gmail.com"
git remote set-url origin git@github-vigil:andrii-habchak/Habitat.git
git ls-remote origin >/dev/null 2>&1 || fail "cannot reach origin over SSH (git@github-vigil:andrii-habchak/Habitat.git)"
ok "git $(git config user.email) → $(git remote get-url origin)"

if $check_only; then ok "preflight passed (only the repo-local git identity/remote were set)"; exit 0; fi

# 3. Run clock
mkdir -p .run
deadline="$(TZ=Europe/Paris date -j -f '%Y-%m-%d %H:%M' "$deadline_str" +%s)" || fail "bad deadline '$deadline_str'"
now="$(date +%s)"
[ "$deadline" -gt $((now + 1800)) ] || fail "deadline is less than 30 minutes away"
echo "$deadline" > .run/deadline
ok "run clock: $(scripts/deadline.sh)"

# 4. QA simulator (one dedicated device; only QA agents boot it)
udid="$(xcrun simctl list devices | grep -F 'Habitat-QA (' | grep -oE '[0-9A-F]{8}-[0-9A-F-]{27}' | head -1 || true)"
if [ -z "$udid" ]; then
  udid="$(xcrun simctl create Habitat-QA com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime")" \
    || fail "could not create the Habitat-QA simulator"
fi
echo "$udid" > .run/sim-udid
ok "QA simulator Habitat-QA $udid"

# 5. Local-only agent settings: clock guard hook + allowlist (git-ignored)
mkdir -p .claude
cat > .claude/settings.local.json <<JSON
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Agent|SendMessage",
        "hooks": [ { "type": "command", "command": "$root/scripts/deadline-guard.sh" } ] }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(scripts/*)", "Bash(./scripts/*)", "Bash(git:*)", "Bash(swift:*)", "Bash(swiftlint:*)",
      "Bash(xcodegen:*)", "Bash(xcodebuild:*)", "Bash(xcrun simctl:*)", "Bash(date:*)"
    ]
  }
}
JSON
for line in '.run/' '.claude/' 'build.noindex/' '*.xcodeproj' 'DerivedData/' '.DS_Store'; do
  grep -qxF "$line" .gitignore 2>/dev/null || echo "$line" >> .gitignore
done
ok "guard hook + local permissions written (git-ignored)"

# 6. Keep the Mac awake until the deadline; notify at FREEZE (T-19) and STOP (T-4)
secs=$((deadline - now))
nohup caffeinate -i -t "$secs" >/dev/null 2>&1 &
nohup bash -c "
  sleep $((secs - 19 * 60)); osascript -e 'display notification \"FREEZE: wrap up, no new work\" with title \"Habitat run\"'
  sleep $((15 * 60));        osascript -e 'display notification \"STOP: end the session\" with title \"Habitat run\"'
" >/dev/null 2>&1 &
ok "caffeinate + FREEZE/STOP notifications armed"

# 7. Prompt
human="$(date -r "$deadline" '+%A %d %b %H:%M %Z')"
prompt="$(awk 'found { print } /^---$/ { found = 1 }' docs/NEXT.md | sed "s|{{DEADLINE}}|$human|")"
echo; echo "──────── orchestrator prompt ────────"
printf '%s\n' "$prompt"
if printf '%s\n' "$prompt" | pbcopy; then echo; echo "(Copied to the clipboard. Repository: $root)"; fi
