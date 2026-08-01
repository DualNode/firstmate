#!/usr/bin/env bash
# Cursor sessionStart adapter for the firstmate PRIMARY session-start nudge.
# See docs/sessionstart-nudge.md for the complete contract this delegates to.
#
# Cursor's sessionStart hook fires correctly but its plain stdout does NOT
# reach model context (verified live) - unlike Claude/Codex's plain-stdout
# SessionStart convention, it must return JSON {"additional_context": "..."}
# on stdout instead. This adapter runs the shared bin/fm-sessionstart-nudge.sh
# wrapper (the same one-line nudge every other harness already uses) and
# translates its plain stdout into that JSON shape.
set -u

PAYLOAD=$(cat 2>/dev/null || true)

command -v jq >/dev/null 2>&1 || { printf '{}'; exit 0; }

ROOT=$(printf '%s' "$PAYLOAD" | jq -r '.workspace_roots[0] // empty' 2>/dev/null) || ROOT=
if [ -z "$ROOT" ]; then
  ROOT=$(pwd -P) || { printf '{}'; exit 0; }
fi
[ -x "$ROOT/bin/fm-sessionstart-nudge.sh" ] || { printf '{}'; exit 0; }

NUDGE=$("$ROOT/bin/fm-sessionstart-nudge.sh" 2>/dev/null) || NUDGE=
[ -n "$NUDGE" ] || { printf '{}'; exit 0; }

jq -n --arg ctx "$NUDGE" '{additional_context: $ctx}'
exit 0
