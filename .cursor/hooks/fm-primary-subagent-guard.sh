#!/usr/bin/env bash
# Cursor preToolUse adapter for the firstmate PRIMARY delegation-shape guard.
# See docs/subagent-guard.md for the complete contract this delegates to.
#
# subagentStart/subagentStop do not fire in this build (verified: a
# subagentStart deny hook never logged and never blocked two live Task calls,
# while the general preToolUse/beforeShellExecution hook mechanism fired
# correctly in the same sessions), so the guard is wired through preToolUse
# matched to tool type Task instead - this exact combination is live-verified
# (a deny hook denied a real Task tool call end to end).
set -u

PAYLOAD=$(cat 2>/dev/null || true)
[ -n "$PAYLOAD" ] || { printf '{}'; exit 0; }

command -v jq >/dev/null 2>&1 || { printf '{}'; exit 0; }

ROOT=$(printf '%s' "$PAYLOAD" | jq -r '.workspace_roots[0] // empty' 2>/dev/null) || ROOT=
if [ -z "$ROOT" ]; then
  ROOT=$(pwd -P) || { printf '{}'; exit 0; }
fi
[ -x "$ROOT/bin/fm-subagent-pretool-check.sh" ] || { printf '{}'; exit 0; }

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null) || TOOL=
[ -n "$TOOL" ] || { printf '{}'; exit 0; }

OUT=$("$ROOT/bin/fm-subagent-pretool-check.sh" --tool "$TOOL" 2>/dev/null)
RC=$?
if [ "$RC" -ne 2 ]; then
  printf '{}'
  exit 0
fi

REASON=$(printf '%s' "$OUT" | jq -r '.reason // empty' 2>/dev/null) || REASON=
[ -n "$REASON" ] || REASON="[subagent-dispatch] the firstmate primary dispatches through the fleet, not the harness's own delegation tools (blocked tool: $TOOL)."

jq -n --arg reason "$REASON" '{permission:"deny",user_message:$reason,agent_message:$reason}'
exit 0
