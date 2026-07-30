#!/usr/bin/env bash
# Cursor beforeShellExecution adapter for the firstmate PRIMARY watcher-arm
# guard seatbelt. See docs/arm-pretool-check.md for the complete contract
# this delegates to.
#
# beforeShellExecution is the live-verified event for a Cursor shell command:
# it fires with the exact command string on the payload's .command field
# (confirmed in the same investigation that proved subagentStart/subagentStop
# are non-functional for this build; see docs/subagent-guard.md).
set -u

PAYLOAD=$(cat 2>/dev/null || true)
[ -n "$PAYLOAD" ] || { printf '{}'; exit 0; }

command -v jq >/dev/null 2>&1 || { printf '{}'; exit 0; }

ROOT=$(printf '%s' "$PAYLOAD" | jq -r '.workspace_roots[0] // empty' 2>/dev/null) || ROOT=
if [ -z "$ROOT" ]; then
  ROOT=$(pwd -P) || { printf '{}'; exit 0; }
fi
[ -x "$ROOT/bin/fm-arm-pretool-check.sh" ] || { printf '{}'; exit 0; }

CMD=$(printf '%s' "$PAYLOAD" | jq -r '.command // empty' 2>/dev/null) || CMD=
[ -n "$CMD" ] || { printf '{}'; exit 0; }

OUT=$("$ROOT/bin/fm-arm-pretool-check.sh" --command "$CMD" 2>/dev/null)
RC=$?
if [ "$RC" -ne 2 ]; then
  printf '{}'
  exit 0
fi

REASON=$(printf '%s' "$OUT" | jq -r '.reason // empty' 2>/dev/null) || REASON=
[ -n "$REASON" ] || REASON="[watcher-background] a protected watcher command cannot run in an asynchronous shell list or through nohup/disown."

jq -n --arg reason "$REASON" '{permission:"deny",user_message:$reason,agent_message:$reason}'
exit 0
