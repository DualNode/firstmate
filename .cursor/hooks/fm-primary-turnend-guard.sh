#!/usr/bin/env bash
# Cursor stop-hook adapter for the firstmate PRIMARY turn-end guard.
# See docs/turnend-guard.md "Harness integrations" for the contract this
# implements and docs/verification/supervision.md for live evidence.
#
# Cursor's stop hook is passive: exit status cannot block a turn end, but
# returning {"followup_message": "..."} on stdout injects it as a new
# user-shaped turn (verified live). Cursor's own loop_count stdin field
# increments on each stop within a forced-continuation chain, so it stands in
# for a hand-rolled loop guard exactly the way Codex's stop_hook_active does:
# loop_count > 0 means this stop already follows a forced continuation this
# turn, so it is translated into a synthetic stop_hook_active=true payload for
# the shared predicate's existing "never block twice" default-mode logic
# rather than reimplementing that guard here.
#
# This same tracked script also carries the crew turn-end signal: a crew
# worktree is a checkout of this repo, so its .cursor/hooks.json is this
# very tracked file, not a writable per-task file. fm-spawn.sh drops an
# untracked .fm-cursor-turnend pointer naming the task's turn-ended marker;
# below, if that pointer exists, it is touched before anything else. That is
# harmless to run alongside the primary-guard logic that follows, since that
# logic already self-scopes to a safe no-op in a crew worktree via
# bin/fm-turnend-guard.sh's own fm_primary_scope_matches check.
set -u

PAYLOAD=$(cat 2>/dev/null || true)
[ -n "$PAYLOAD" ] || { printf '{}'; exit 0; }

command -v jq >/dev/null 2>&1 || { printf '{}'; exit 0; }

ROOT=$(printf '%s' "$PAYLOAD" | jq -r '.workspace_roots[0] // empty' 2>/dev/null) || ROOT=
if [ -z "$ROOT" ]; then
  ROOT=$(pwd -P) || { printf '{}'; exit 0; }
fi

POINTER="$ROOT/.fm-cursor-turnend"
if [ -f "$POINTER" ]; then
  CREW_TARGET=
  IFS= read -r CREW_TARGET < "$POINTER" 2>/dev/null || true
  case "$CREW_TARGET" in
    /*.turn-ended) touch "$CREW_TARGET" 2>/dev/null || true ;;
  esac
fi

[ -x "$ROOT/bin/fm-turnend-guard.sh" ] || { printf '{}'; exit 0; }

LOOP_COUNT=$(printf '%s' "$PAYLOAD" | jq -r '.loop_count // 0' 2>/dev/null) || LOOP_COUNT=0
case "$LOOP_COUNT" in ''|*[!0-9]*) LOOP_COUNT=0 ;; esac
if [ "$LOOP_COUNT" -gt 0 ]; then
  SYNTH='{"stop_hook_active":true}'
else
  SYNTH='{"stop_hook_active":false}'
fi

ERR=$(mktemp "${TMPDIR:-/tmp}/fm-turnend-cursor.XXXXXX") || { printf '{}'; exit 0; }
trap 'rm -f "$ERR"' EXIT

printf '%s' "$SYNTH" | "$ROOT/bin/fm-turnend-guard.sh" 2>"$ERR"
RC=$?
if [ "$RC" -ne 2 ]; then
  printf '{}'
  exit 0
fi

REASON=$(cat "$ERR" 2>/dev/null || true)
[ -n "$REASON" ] || REASON='tasks in flight, no live watcher - repair missing watcher supervision according to the session-start operating block before ending the turn'

if [ -f "$ROOT/bin/fm-operational-input.sh" ]; then
  # shellcheck source=bin/fm-operational-input.sh
  . "$ROOT/bin/fm-operational-input.sh"
  fm_operational_input_encode turn-end-guard \
    "TURN WOULD END BLIND - supervision is off. Repair missing watcher supervision according to the session-start operating block before ending the turn.

$REASON" \
    MSG || { printf '{}'; exit 0; }
else
  MSG="TURN WOULD END BLIND - supervision is off. Repair missing watcher supervision according to the session-start operating block before ending the turn.

$REASON"
fi

printf '%s' "$MSG" | jq -Rs '{followup_message: .}'
exit 0
