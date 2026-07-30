Mode: Cursor primary turn-end guard only; no verified watcher-arm background-wake mechanism yet.

Cursor's `stop` hook is passive (verified; see the `cursor` section of `harness-adapters`): it cannot block a turn directly, but a project `.cursor/hooks.json` `stop` hook can return `{"followup_message": "..."}` to force one bounded follow-up turn, using Cursor's own `loop_count` payload field as the loop guard instead of hand-rolled state.
The tracked `.cursor/hooks/fm-primary-turnend-guard.sh` implements this against the shared `bin/fm-turnend-guard.sh` predicate, the same way the OpenCode and Pi adapters force one follow-up from their own passive lifecycle callbacks.

No verified background task mechanism exists yet that survives the tool call and wakes the model on process exit (`bin/fm-watch-arm.sh`'s contract), so a Cursor primary session must follow the generic fallback in [`unknown.md`](unknown.md): a bounded foreground wait over `bin/fm-watch.sh`, never shell `&`.
Do not promote Cursor to a background-arm protocol until that mechanism is verified in a scratch project and this file is updated with the exact command, the same rigor `docs/verification/supervision.md` records for the other adapters.

When this session owns supervision and away mode is not active:
1. Drain first with `bin/fm-wake-drain.sh`.
2. Choose a bounded foreground wait the harness can actually wake from (see `unknown.md`); do not arm `bin/fm-watch-arm.sh` for Cursor.
3. Ordinary wake: drain and handle the wake, then repeat the same verified wait while supervision is still required.
4. The turn-end guard backstop above still forces one bounded follow-up if a turn would otherwise end blind; treat it as a backstop, not the normal wake path.
5. Never use shell `&` for watcher supervision.

Interactive TUI primary sessions are the supported host; a headless `cursor-agent --print` call exits after its first response and cannot serve as the primary session.
