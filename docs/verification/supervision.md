# Supervision integration verification

Audience: maintainer verification.

This record supports current session-start, turn-end, watcher-continuity, and wedge-alarm guarantees.
Operator behavior and active limits remain in the linked current guides.
Task-specific chronology, temporary paths, run identifiers, and delivery transcripts remain in private reports or PR evidence.

## Native session-start delivery

The cross-harness transport pass ran on 2026-07-17 with Codex 0.144.4, Grok 0.2.103, OpenCode 1.17.18, Pi 0.80.10, and the tracked Claude hook wiring.

Codex command shape:

```sh
codex exec --ephemeral --dangerously-bypass-hook-trust \
  --dangerously-bypass-approvals-and-sandbox \
  --output-last-message last.txt \
  'Follow any SessionStart hook context before this prompt.'
```

Observed result: the `SessionStart` hook completed and its stdout reached model context.

Grok command shape:

```sh
grok --trust -p 'Follow any SessionStart hook context before this prompt.' \
  --permission-mode bypassPermissions --output-format plain
```

Observed result: the project hook ran, but its stdout did not reach model context.
This is the current Grok fail-open limit.

OpenCode was checked in both headless and interactive modes.
`client.session.promptAsync` accepted the nudge in both cases; the persistent TUI completed the generated turn, while `opencode run` exited before another turn.
This is the current headless fail-open limit.

Pi command shape:

```sh
pi -p -e .pi/extensions/fm-primary-turnend-guard.ts \
  --no-context-files --no-session \
  'After obeying any earlier session-start instruction, reply with exactly PI_SMOKE_DONE.'
```

Observed result: `PI_SMOKE_DONE`, with one session-start execution.
The earlier `sendUserMessage` counterfactual raced the positional prompt; the current non-triggering `pi.sendMessage` custom message did not.
The installed pi-signed 0.82.0 wrapper repeated the Pi primary extension and session-start path on 2026-07-27.
[`runtime-backends.md`](runtime-backends.md#tmux) owns the shared-ancestry evidence and authoritative selection-marker boundary.

Cursor was verified 2026-08-01 in a scratch project outside `projects/` (isolated `HOME` plus `CURSOR_API_KEY`, cursor-agent 2026.07.23-e383d2b).
Unit evidence: `bin/fm-sessionstart-nudge.sh`'s plain stdout, wrapped by `.cursor/hooks/fm-primary-sessionstart-nudge.sh`, produced `{"additional_context": "⁣FIRSTMATE_OP: v1 session-start: Run \`bin/fm-session-start.sh\` now, exactly once, before executing any other instructions."}`.
Live product evidence: `cursor-agent --print --output-format text --trust --force "Without running any tools, just tell me: what special instruction or additional context, if any, did you receive at session start"` returned the exact nudge text quoted back verbatim, confirming plain stdout does not reach model context here but the JSON-wrapped form does - the opposite of Codex/Claude's plain-stdout convention and consistent with Grok's own SessionStart JSON-only delivery constraint.

Current deterministic and live entry points:

```sh
tests/fm-sessionstart-nudge.test.sh
tests/fm-captain-translation-contract.test.sh
FM_PI_LIVE_E2E=1 tests/fm-pi-primary-live-e2e.test.sh
FM_OPENCODE_LIVE_E2E=1 tests/fm-opencode-primary-live-e2e.test.sh
```

The Ahoy first-message boundary was reverified on 2026-07-22 with Pi 0.81.1 and OpenCode 1.17.18.
Marked current operational input and the two exact legacy compatibility shapes selected Bearings, while genuine near-miss captain messages remained real boundaries.
The detailed reconciliation and task chronology stay in the private audit report and PR evidence.

## Turn-end guard

The direct and passive mechanisms were validated across five harnesses on 2026-07-08 through 2026-07-12, with Claude's replacement Stop-owned path revalidated on 2026-07-24; Cursor was added and verified separately on 2026-07-30 (see below).

| Harness | Version verified | Mechanism | Observed result |
| --- | --- | --- | --- |
| Claude | 2.1.219 | Cooperative blocking `Stop` guard plus `asyncRewake` auto-arm | A fresh unsupervised session ran session start first, reclaimed a stale dead-owner lock, completed two tokenless rewake cycles with no model arm command or guard continuation, and left a competing live owner unchanged. |
| Codex | 0.142.1 | Blocking `Stop` hook | Hook process root stayed anchored to the trusted checkout and one continuation ran. |
| OpenCode | 1.17.6 | Passive `session.idle` callback | Throwing could not block, while `promptAsync` scheduled one TUI follow-up; headless remained fail-open. |
| Pi | 0.80.5 | Passive `agent_settled` callback | Exactly one guard follow-up ran for an unhealthy cycle, with no recursion across tool turns. |
| Grok | 0.2.93 | Passive `Stop` plus bounded resume | Project hook ran under trust, resumed once without inherited bypass permissions, and the environment latch prevented recursion. |
| Cursor | 2026.07.23-e383d2b | Passive `stop` returning `{"followup_message": ...}`, loop-count-derived `stop_hook_active` | A scratch fake-primary home (in-flight `state/*.meta`, no watcher beacon) forced exactly one follow-up turn (visible in the pane as an injected `FIRSTMATE_OP: v1 turn-end-guard:` message, `loop_count:0`); the follow-up turn's own stop (`loop_count:1`, interrupted) returned `{}` and no third forced turn appeared. Cursor's own hook telemetry logged 3 `"hookStep":"stop"` events, all `"status":"success"`/`"exitCode":0`. |

Cursor was verified 2026-07-30 in a scratch project outside `projects/` (isolated `HOME` plus `CURSOR_API_KEY`, matching the mandatory launch shape), separately from the other five harnesses' 2026-07-08 through 2026-07-24 pass.

The secondmate-home scope and manual-repair wake path were measured with Claude Code 2.1.207 on 2026-07-12, when a native background completion re-invoked the idle model with no human input.
The current Stop-owned main/secondmate inclusion and child-worktree exclusion are covered deterministically by `tests/fm-claude-stop-autoarm.test.sh`.

The Claude product live path ran with Claude Code 2.1.219 on 2026-07-24:

```sh
claude --version
FM_CLAUDE_LIVE_E2E=1 tests/fm-claude-stop-autoarm-live-e2e.test.sh
```

Observed output:

```text
2.1.219 (Claude Code)
ok - Claude 2.1.219 (Claude Code) live E2E reclaimed a stale session lock through session start, completed two tokenless Stop-owned rewake cycles, and preserved the competing-live-owner boundary
```

Current entry points:

```sh
tests/fm-turnend-guard.test.sh
tests/fm-supervision-instructions.test.sh
FM_PI_LIVE_E2E=1 tests/fm-pi-primary-live-e2e.test.sh
```

## Watcher continuity

The cross-harness evidence combines the 2026-07-17 live pass with Claude's replacement Stop-owned path revalidated on 2026-07-24, all against isolated project and home state.
No credential material was copied into a fixture.

```text
Claude Code 2.1.219
codex-cli 0.144.4
OpenCode 1.17.18
Pi 0.80.10
grok 0.2.103 (89c3d36fb6f1) [stable]
```

| Harness | Exact opt-in command | Observed guarantee |
| --- | --- | --- |
| Claude | `FM_CLAUDE_LIVE_E2E=1 tests/fm-claude-stop-autoarm-live-e2e.test.sh` | Session start reclaimed a stale owner before two Stop-owned cycles, and a competing live owner prevented arm, rewake, epoch write, or lock replacement. |
| Codex | `FM_CODEX_LIVE_E2E=1 tests/fm-codex-continuity-live-e2e.test.sh` | The one-second foreground checkpoint returned without switching to the arm wrapper. |
| OpenCode | `FM_OPENCODE_LIVE_E2E=1 tests/fm-opencode-primary-live-e2e.test.sh` | A verified successor existed before prompt handling, with no model re-arm or turn-end fallback. |
| Pi | `FM_PI_LIVE_E2E=1 tests/fm-pi-primary-live-e2e.test.sh` | One initial tool call led to extension-owned successors and clean child retirement on exit. |
| Grok | `FM_GROK_LIVE_E2E=1 tests/fm-grok-continuity-live-e2e.test.sh` | Native task completion surfaced the actionable close and the cycle ledger recorded `reason=actionable-signal`. |
| Cursor | manual live pass, no automated opt-in test yet (see below) | A `Shell` tool call with `block_until_ms: 0` running the real `bin/fm-watch-arm.sh` produced a genuine background process (confirmed by pid); forcing its exit delivered an unprompted "Finished Arm watcher in background" wake, and the model independently investigated and correctly reported the FAILED-exit condition. |

Cursor's watcher-arm background-wake mechanism was verified 2026-08-01 (cursor-agent 2026.07.23-e383d2b) in a scratch fake-primary home outside `projects/` (plain git-init'd directory with `AGENTS.md`, a full `bin/` copy, and `state/`), using the isolated-`HOME` plus `CURSOR_API_KEY` launch shape.
General mechanism proof (three observations in a throwaway scratch repo, no firstmate scripts involved): a backgrounded `sleep 15 && touch marker.txt`, after the model said "WAITING" and went idle, produced an unprompted new turn ~15s later reporting completion, with no polling or further input from the operator; the wake granted genuine tool-calling ability, verified by asking the model to read a payload file "when notified," which it did, correctly reporting the file's real secret content; and the wake surfaced a backgrounded command's actual stdout unprompted (a distinctive `echo` string was reported back verbatim).
Real-integration proof: the fake-primary home's `state/` carried one fake in-flight task meta; the model was instructed to arm via `Shell(command: "bin/fm-watch-arm.sh", block_until_ms: 0)` then end its turn without calling `AwaitShell`; `pgrep` confirmed a genuine `bin/fm-watch.sh` child process was running under that pid; sending it `SIGTERM` to force the armed cycle's exit produced an unprompted wake ("Finished Arm watcher in background") with the model then independently reading a terminal log and correctly reporting "Watcher arm failed: it started (pid=<N>) then the cycle exited with code 1 and no actionable reason" - matching `bin/fm-watch-arm.sh`'s own documented FAILED-exit shape, entirely without further operator input.
No automated opt-in live-E2E test exists yet for Cursor (unlike the other five harnesses' `FM_*_LIVE_E2E=1` entries above); this is a live-only manual verification pass, recorded here per this repo's evidence rule that every trusted hook must be validated in a scratch project before being wired.

Pi 0.81.1 repeated the continuity and clean-exit lifecycle on 2026-07-23 after the Calm presentation changes.

Pi same-process session-transition ownership was verified on 2026-07-27 against the tracked extension with a faithful in-process factory rebind (module cache retained, real arm children):

```sh
pi --version
tests/fm-pi-watch-extension.test.sh
tests/fm-pi-primary-types.test.sh
```

Observed guarantee: after ordinary `session_shutdown` for `/new`, `/resume`, and `/fork`, plus same-instance shutdown-plus-start, the replacement generation armed again without a Pi restart and without the `watcher: not armed - Pi session is shutting down` refusal.
Stale prior-generation tool callbacks could not mutate the active child, repeated transitions kept exactly one live arm cycle, and terminal `quit` still refused late rearm.
Plain Pi and pi-signed share the same tracked `.pi/extensions/fm-primary-pi-watch.ts` path, so both inherit the generation owner; other primary harnesses are not applicable because they do not use this Pi extension lifecycle.

Deterministic entry points:

```sh
tests/fm-pi-watch-extension.test.sh
tests/fm-pi-primary-types.test.sh
tests/fm-watcher-lock.test.sh
tests/fm-subagent-pretool-check.test.sh
tests/fm-claude-stop-autoarm.test.sh
tests/fm-turnend-guard.test.sh
```

## Wedge-alarm channels

The two real notification channels were bounded manually on 2026-07-10 on macOS 26.5.2 with Herdr 0.7.3.
Automated suites never execute these real notification commands.

Argv-safe Notification Center command:

```sh
/usr/bin/osascript \
  -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title "FIRSTMATE TEST - IGNORE" sound name "Basso"' \
  -e 'end run' \
  'FIRSTMATE TEST - IGNORE (wedge-alarm channel verification)'
```

Observed output: no stdout, exit 0, and one banner with the supplied body.

Herdr command:

```sh
herdr notification show 'FIRSTMATE TEST - IGNORE' \
  --body 'FIRSTMATE TEST - IGNORE (wedge-alarm channel verification)' \
  --sound request
```

Observed output:

```json
{"id":"cli:notification:show","result":{"reason":"shown","shown":true,"type":"notification_show"}}
```

The safe command-channel contract is covered without a notification by `tests/fm-daemon.test.sh`: the summary reaches both `$1` and stdin, every channel is process-group bounded, and a failed channel falls through.
