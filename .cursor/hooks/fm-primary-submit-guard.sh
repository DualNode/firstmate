#!/usr/bin/env bash
# Cursor beforeSubmitPrompt adapter for the semantic busy-state contract
# owned by bin/fm-busy-lib.sh (source: cursor-hook).
#
# beforeSubmitPrompt fires once per submitted turn, live-verified
# (2026-08-02, cursor-agent 2026.07.23-e383d2b) in a real interactive
# session to bracket a turn together with the stop hook below: a prompt
# submitted through the composer fired beforeSubmitPrompt immediately, and
# the matching stop fired only once the turn's own work finished.
#
# A crew worktree is a checkout of this same repo, so its .cursor/hooks.json
# IS this tracked file, not a writable per-task one - like the turn-end
# pointer, fm-spawn.sh drops an untracked .fm-cursor-busy pointer naming the
# task's busy-state dir, id, and armed gen. The firstmate PRIMARY session
# carries no such pointer (busy-state records exist only for crew tasks
# under state/<id>.busy-state; AGENTS.md and bin/fm-busy-lib.sh never define
# one for a primary session), so this hook safely no-ops there.
set -u

PAYLOAD=$(cat 2>/dev/null || true)
[ -n "$PAYLOAD" ] || { printf '{}'; exit 0; }

command -v jq >/dev/null 2>&1 || { printf '{}'; exit 0; }

ROOT=$(printf '%s' "$PAYLOAD" | jq -r '.workspace_roots[0] // empty' 2>/dev/null) || ROOT=
if [ -z "$ROOT" ]; then
  ROOT=$(pwd -P) || { printf '{}'; exit 0; }
fi

POINTER="$ROOT/.fm-cursor-busy"
if [ -f "$POINTER" ] && [ -x "$ROOT/bin/fm-busy-event.sh" ]; then
  STATE='' ID='' GEN=''
  while IFS='=' read -r key val; do
    case "$key" in
      state) STATE=$val ;;
      id) ID=$val ;;
      gen) GEN=$val ;;
    esac
  done < "$POINTER"
  if [ -n "$STATE" ] && [ -n "$ID" ] && [ -n "$GEN" ]; then
    "$ROOT/bin/fm-busy-event.sh" apply "$STATE" "$ID" busy \
      --gen "$GEN" --source cursor-hook --event before-submit-prompt \
      >/dev/null 2>&1 || true
  fi
fi

printf '{}'
exit 0
