#!/usr/bin/env bash
# PreToolUse hook for Agent / SendMessage. Refuses to start or continue agents once the run
# clock says FREEZE or STOP (see docs/PLAN.md §10). Exit 2 blocks the call and shows stderr.
root="$(cd "$(dirname "$0")/.." && pwd)"
input="$(cat)"
state="$("$root/scripts/deadline.sh" | sed -E 's/^STATE=([A-Z]+).*/\1/')"
case "$state" in
  STOP)
    echo "Run clock: STOP. Nothing may start. Finish docs/STATUS.md and docs/NEXT.md, push, end the session." >&2
    exit 2 ;;
  FREEZE)
    if printf '%s' "$input" | grep -q 'WRAPUP'; then exit 0; fi
    echo "Run clock: FREEZE. No new work. Only wrap-up dispatches (prompt must contain the token WRAPUP)." >&2
    exit 2 ;;
esac
exit 0
