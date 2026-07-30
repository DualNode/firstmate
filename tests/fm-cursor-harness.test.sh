#!/usr/bin/env bash
# Behavior tests for Cursor-harness spawn mechanics: the mandatory isolated
# HOME + CURSOR_API_KEY launch shape, the per-task turn-end marker hook, and
# harness detection.
#
# These tests drive fm-spawn through meta writing and launch construction with
# a fake tmux pane and a real isolated git worktree, exactly like
# tests/fm-spawn-dispatch-profile.test.sh. The fake tmux captures the literal
# launch command sent with `tmux send-keys -l`, so assertions pin the exact
# command firstmate would run without starting any real harness.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
TMP_ROOT=$(fm_test_tmproot fm-cursor-harness)

make_spawn_fakebin() {
  local dir=$1 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
case "$*" in
  *"#{pane_current_path}"*) printf '%s\n' "${FM_FAKE_PANE_PATH:-}"; exit 0 ;;
esac
case "${1:-}" in
  display-message) printf 'firstmate\n'; exit 0 ;;
  list-windows) exit 0 ;;
  has-session|new-session|new-window|kill-window) exit 0 ;;
  send-keys)
    if [ -n "${FM_FAKE_LAUNCH_LOG:-}" ]; then
      prev=
      for a in "$@"; do
        if [ "$prev" = "-l" ]; then
          printf '%s\n' "$a" >> "$FM_FAKE_LAUNCH_LOG"
        fi
        prev=$a
      done
    fi
    exit 0
    ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"
  fm_fake_exit0 "$fakebin" treehouse
  printf '%s\n' "$fakebin"
}

make_spawn_case() {
  local name=$1 case_dir home proj wt fakebin launchlog id
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  launchlog="$case_dir/launch.log"
  fakebin=$(make_spawn_fakebin "$case_dir/fake")
  id="cursor-$name-z1"
  mkdir -p "$home/data/$id" "$home/projects" "$home/state" "$home/config"
  printf 'brief for %s\n' "$id" > "$home/data/$id/brief.md"
  fm_git_worktree "$proj" "$wt" "fm/$id"
  touch "$home/state/.last-watcher-beat"
  printf '%s\n' "$case_dir|$home|$proj|$wt|$fakebin|$launchlog|$id"
}

run_cursor_spawn() {
  local home=$1 proj=$2 wt=$3 fakebin=$4 launchlog=$5 id=$6
  : > "$launchlog"
  FM_ROOT_OVERRIDE='' FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_FAKE_PANE_PATH="$wt" TMUX="fake,1,0" \
    FM_FAKE_LAUNCH_LOG="$launchlog" PATH="$fakebin:$PATH" \
    "$SPAWN" "$id" "$proj" cursor 2>&1
}

cleanup_task_tmp() {
  local id=$1
  rm -rf "/tmp/fm-$id"
}

test_cursor_spawn_refuses_without_api_key() {
  local rec case_dir home proj wt fakebin launchlog id out status
  rec=$(make_spawn_case no-key)
  IFS='|' read -r case_dir home proj wt fakebin launchlog id <<EOF
$rec
EOF
  out=$(run_cursor_spawn "$home" "$proj" "$wt" "$fakebin" "$launchlog" "$id")
  status=$?
  expect_code 1 "$status" "cursor spawn without CURSOR_API_KEY should refuse"
  assert_contains "$out" "CURSOR_API_KEY not found" "refusal did not name the missing key"
  assert_absent "$home/state/$id.meta" "a refused cursor spawn should not have recorded meta"
  pass "cursor spawn refuses when CURSOR_API_KEY is absent from .env"
}

test_cursor_spawn_isolated_home_and_key_launch() {
  local rec case_dir home proj wt fakebin launchlog id out status launch expected keyfile
  rec=$(make_spawn_case launch-shape)
  IFS='|' read -r case_dir home proj wt fakebin launchlog id <<EOF
$rec
EOF
  printf 'CURSOR_API_KEY=crsr_test_key_value\n' > "$home/.env"

  out=$(run_cursor_spawn "$home" "$proj" "$wt" "$fakebin" "$launchlog" "$id")
  status=$?
  expect_code 0 "$status" "cursor spawn should succeed with CURSOR_API_KEY present"
  assert_contains "$out" "spawned $id harness=cursor" "spawn did not report cursor"
  assert_grep "harness=cursor" "$home/state/$id.meta" "meta missing harness=cursor"

  launch=$(cat "$launchlog")
  expected="HOME='/tmp/fm-$id/cursor-home' CURSOR_API_KEY=\$(cat '/tmp/fm-$id/cursor-api-key') cursor-agent --trust --force \"\$('${ROOT}/bin/fm-operational-input.sh' encode launch-brief < '$home/data/$id/brief.md')\""
  [ "$launch" = "$expected" ] || fail "cursor launch did not use the isolated-HOME + key shape"$'\n'"expected: $expected"$'\n'"actual:   $launch"

  assert_present "/tmp/fm-$id/cursor-home" "isolated HOME directory was not created"
  keyfile="/tmp/fm-$id/cursor-api-key"
  assert_present "$keyfile" "CURSOR_API_KEY file was not written"
  assert_grep "crsr_test_key_value" "$keyfile" "CURSOR_API_KEY file did not contain the sourced key"
  assert_not_contains "$launch" "crsr_test_key_value" "the raw key value must never appear in the typed launch command"

  cleanup_task_tmp "$id"
  pass "cursor spawn launches with an isolated per-task HOME and reads the key from a private file, never a literal value"
}

test_cursor_spawn_installs_per_task_turnend_hook() {
  local rec case_dir home proj wt fakebin launchlog id out status hookjson hooksh
  rec=$(make_spawn_case turnend-hook)
  IFS='|' read -r case_dir home proj wt fakebin launchlog id <<EOF
$rec
EOF
  printf 'CURSOR_API_KEY=crsr_test_key_value\n' > "$home/.env"

  out=$(run_cursor_spawn "$home" "$proj" "$wt" "$fakebin" "$launchlog" "$id")
  status=$?
  expect_code 0 "$status" "cursor spawn should succeed"

  hookjson="$wt/.cursor/hooks.json"
  hooksh="$wt/.cursor/hooks/fm-turn-end.sh"
  assert_present "$hookjson" "cursor per-task hooks.json was not installed"
  assert_present "$hooksh" "cursor per-task turn-end hook script was not installed"
  assert_grep '"stop"' "$hookjson" "cursor per-task hooks.json did not register a stop hook"
  assert_grep '.cursor/hooks/fm-turn-end.sh' "$hookjson" "cursor per-task hooks.json did not point at the turn-end script"
  [ -x "$hooksh" ] || fail "cursor per-task turn-end hook script is not executable"

  local exclude_file
  exclude_file=$(git -C "$wt" rev-parse --git-path info/exclude)
  assert_grep '.cursor/hooks.json' "$exclude_file" "cursor hooks.json was not excluded from git"
  assert_grep '.cursor/hooks/fm-turn-end.sh' "$exclude_file" "cursor turn-end hook script was not excluded from git"

  local target
  target="$home/state/$id.turn-ended"
  [ ! -e "$target" ] || fail "turn-end marker should not exist before the hook fires"
  local hookout
  hookout=$(bash "$hooksh" < /dev/null)
  [ -e "$target" ] || fail "cursor turn-end hook did not touch the turn-end marker"
  [ "$hookout" = "{}" ] || fail "cursor turn-end hook must emit valid empty JSON on stdout, got: $hookout"

  cleanup_task_tmp "$id"
  pass "cursor spawn installs a per-task turn-end hook that touches the marker and emits valid JSON"
}

test_cursor_harness_detection() {
  local out
  out=$(env -u CLAUDECODE -u PI_CODING_AGENT -u GROK_AGENT \
    CURSOR_AGENT=1 "$ROOT/bin/fm-harness.sh")
  [ "$out" = "cursor" ] || fail "fm-harness.sh did not detect CURSOR_AGENT=1 as cursor, got: $out"
  pass "fm-harness.sh detects the CURSOR_AGENT=1 env marker"
}

test_cursor_busy_regex() {
  # shellcheck source=bin/fm-tmux-lib.sh
  . "$ROOT/bin/fm-tmux-lib.sh"
  printf '%s' $'→ Add a follow-up                                    ctrl+c to stop' \
    | fm_busy_lines_match cursor \
    || fail "cursor busy regex did not match the literal ctrl+c to stop footer"
  if printf '%s' $'⠘⠣ Working' | fm_busy_lines_match cursor; then
    fail "cursor busy regex must not match on the rotating gerund/spinner word alone"
  fi
  pass "cursor busy regex matches only the stable ctrl+c to stop footer, not the rotating spinner word"
}

test_cursor_spawn_refuses_without_api_key
test_cursor_spawn_isolated_home_and_key_launch
test_cursor_spawn_installs_per_task_turnend_hook
test_cursor_harness_detection
test_cursor_busy_regex
