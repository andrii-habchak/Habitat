#!/usr/bin/env bash
# Prints the run clock. STATE: RUN | FREEZE (no new work, wrap up) | STOP (everything idle).
# The deadline (epoch seconds) is written by scripts/kickoff.sh to .run/deadline.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
file="$root/.run/deadline"
if [ ! -f "$file" ]; then
  echo "STATE=RUN MIN_LEFT=unlimited (no .run/deadline)"
  exit 0
fi
deadline="$(cat "$file")"
now="$(date +%s)"
left=$(( (deadline - now) / 60 ))
if   [ "$left" -le 4 ];  then state=STOP
elif [ "$left" -le 19 ]; then state=FREEZE
else state=RUN
fi
echo "STATE=$state MIN_LEFT=$left NOW=$(date '+%a %H:%M %Z') DEADLINE=$(date -r "$deadline" '+%a %H:%M %Z')"
