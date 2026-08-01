Mode: Cursor background-notify supervision.

Cursor arms through the model's own `Shell` tool call with `block_until_ms: 0`, which starts a command in the background and returns control immediately (verified live, cursor-agent 2026.07.23-e383d2b). When that backgrounded command later exits, cursor-agent autonomously wakes the model with a full new tool-calling turn - no polling, no `AwaitShell` call, no further input needed - and surfaces the command's own stdout in that wake. This is the "background task that survives the tool call and notifies the model on process exit" contract `bin/fm-watch-arm.sh`'s own header comment requires, achieved through a different mechanism than Claude's Stop `asyncRewake` hook or Grok's tracked background tool but to the same effect.

`block_until_ms: 0` is the harness-native tracked background mechanism here, not a shell-level backgrounding hack - never use a shell `&` instead, which is forbidden for every harness and is additionally denied by the wired `beforeShellExecution` arm-guard seatbelt (`docs/arm-pretool-check.md`).

When this session owns supervision and away mode is not active:
1. Drain first with `bin/fm-wake-drain.sh`.
2. First cycle: call `Shell` with `command: "bin/fm-watch-arm.sh"` (or `--restart` for a forced repair) and `block_until_ms: 0`, then end the turn without calling `AwaitShell`.
3. Trust only the arm's own printed status line, delivered in the autonomous wake once the armed process exits: `watcher: started ...` or `watcher: attached ...` means a live cycle existed at arm time; `watcher: FAILED ...` means supervision could not be confirmed and needs repair.
4. After a successful start or attach status, end the turn. The backgrounded arm remains the live wait until it returns an actionable wake or failure - do not call `Shell`/`AwaitShell` again to "check on it" in the meantime.
5. Waiting is silent.
6. Never use shell `&` for firstmate supervision.
7. Never bundle the arm onto another command. A shell `&`, a truncating pipe, or bundling is denied automatically by the PreToolUse-equivalent seatbelt (`.cursor/hooks/fm-primary-arm-guard.sh`) wired through `beforeShellExecution`.

When you see the autonomous wake notification for the arm (its own tool-result summary plus the delivered stdout):
1. Run `bin/fm-wake-drain.sh` first.
2. Handle `signal`, `stale`, `check`, or `heartbeat` using the harness-neutral contract in `AGENTS.md`.
3. Ordinary wake: re-arm the next cycle with the same background `Shell` + `block_until_ms: 0` call to `bin/fm-watch-arm.sh` if work remains in flight or X mode still needs polling.
4. Do not invent a wake from the arm's own status line alone if it only reports `started`/`attached` with no further reason - that is confirmation the cycle exists, not a wake by itself; only the later autonomous notification carrying the watcher's own exit output is the real wake signal.
5. See [`watcher-continuity.md`](../watcher-continuity.md) for the arm-layer successor and clean-close failure contract shared by every harness.

Cursor's `stop` hook is passive. The primary hook `.cursor/hooks/fm-primary-turnend-guard.sh` forces at most one bounded follow-up via `{"followup_message": ...}` when a turn would end blind. That is a backstop, not the normal wake path.

Interactive TUI primary sessions are the supported host; a headless `cursor-agent --print` call exits after its first response and cannot serve as the primary session.
