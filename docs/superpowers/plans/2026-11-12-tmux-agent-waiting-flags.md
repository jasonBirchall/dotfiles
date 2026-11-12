# tmux Agent-Waiting Flags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code hooks set a per-window tmux flag so window pills show when an agent is waiting on Jason, clearing the moment he responds.

**Architecture:** One POSIX-sh hook script in `local-config/hooks/` is registered for five Claude Code hook events in `settings.json`; it sets/unsets a window-scoped user option `@claude_waiting` via `$TMUX_PANE`. The window pill formats in `tmux/tmux.conf` render the option conditionally. Event-driven; no polling.

**Tech Stack:** POSIX sh, tmux user options + format conditionals, Claude Code hooks.

**Spec:** `docs/superpowers/specs/2026-11-12-tmux-agent-waiting-flags-design.md`

## Global Constraints

- Hook script and `settings.json` live in `~/Documents/workarea/local-config` (separate repo, symlinked to `~/.claude`); tmux format changes live in this repo.
- The hook script must **always** exit 0 — a non-zero `UserPromptSubmit` hook blocks the user's prompt in Claude Code.
- Call `tmux` with `$HOME/.nix-profile/bin` prepended to PATH (today's status-bar outage: hook/server environments may lack nix paths).
- Colours stay in the existing gruvbox-muted palette (`tmux/tmux.conf:126-132`); orange `#fe8019` is the established attention colour.
- Commits are YubiKey-signed: stage files and hand Jason the exact `git commit` commands; never commit from the agent shell. Conventional commit subjects, no Co-Authored-By trailer.

## Review Focus

- Claude running outside tmux (`$TMUX_PANE` unset) → script exits 0 silently. (Test in Task 1.)
- Hook fires after its window/pane is gone → `tmux set -t` fails; stderr suppressed, still exit 0. (Test in Task 1.)
- Malformed `settings.json` would break **all** hooks including the existing dangerous-git guard → JSON-validate after editing. (Step in Task 2.)
- Permission approved mid-turn: without a clear on tool activity the pill would keep saying `✋` while Claude works — `PostToolUse` clears it. (Covered by Task 2 registration; manual E2E in Task 3.)
- `#{@claude_waiting}` conditional must not corrupt the pill when the option was never set (empty string ≠ `ask`/`done`). (Test in Task 3.)

---

### Task 1: Hook script (`local-config` repo)

**Files:**
- Create: `~/Documents/workarea/local-config/hooks/tmux-agent-flag.sh` (mode 755)

**Interfaces:**
- Produces: `tmux-agent-flag.sh {ask|done|clear}` — sets window option `@claude_waiting` to `ask`/`done`, or unsets it; always exits 0.

- [ ] **Step 1: Write the script**

```sh
#!/bin/sh
# Claude Code hook: flag/unflag this window's pill in the tmux status bar.
# Usage: tmux-agent-flag.sh ask|done|clear  (always exits 0 — a non-zero
# UserPromptSubmit hook would block the prompt).
PATH="$HOME/.nix-profile/bin:$PATH"
[ -n "$TMUX_PANE" ] || exit 0
case "$1" in
  ask|done) tmux set-option -w -t "$TMUX_PANE" @claude_waiting "$1" 2>/dev/null ;;
  clear)    tmux set-option -w -t "$TMUX_PANE" -u @claude_waiting 2>/dev/null ;;
esac
exit 0
```

`chmod 755` it.

- [ ] **Step 2: Verify against a scratch tmux server**

Run (scratch socket, no effect on the live server):
```sh
tmux -L flagtest new-session -d -s t
PANE=$(tmux -L flagtest display -p -t t '#{pane_id}')
TMUX_PANE=$PANE tmux -L flagtest run-shell true  # warm-up; then:
TMUX_PANE=$PANE sh ~/Documents/workarea/local-config/hooks/tmux-agent-flag.sh ask
tmux -L flagtest show-options -w -t "$PANE" @claude_waiting   # expect: @claude_waiting ask
TMUX_PANE=$PANE sh .../tmux-agent-flag.sh clear
tmux -L flagtest show-options -w -t "$PANE" @claude_waiting   # expect: no output
TMUX_PANE= sh .../tmux-agent-flag.sh ask; echo $?             # expect: 0
TMUX_PANE=%999 sh .../tmux-agent-flag.sh ask; echo $?         # expect: 0, no stderr
tmux -L flagtest kill-server
```
Note: the scratch-server tmux commands need `tmux -L flagtest`; the script itself talks to the server owning `$TMUX_PANE` — for the stale-pane and unset cases that's irrelevant. For the `ask`/`clear` assertions, run the script with `TMUX=` pointing at the flagtest socket or verify on the live server with a throwaway window.

- [ ] **Step 3: Stage and hand off commit**

```sh
git -C ~/Documents/workarea/local-config add hooks/tmux-agent-flag.sh
```
Give Jason: `git -C ~/Documents/workarea/local-config commit -m "feat: tmux window flag hook for agent-waiting status"` (run with `!` prefix; combined with Task 2's staging if preferred).

### Task 2: Hook registration (`local-config` repo)

**Files:**
- Modify: `~/Documents/workarea/local-config/settings.json` (`hooks` object; currently only `PreToolUse`)

**Interfaces:**
- Consumes: `tmux-agent-flag.sh` from Task 1 via its `~/.claude/hooks/` symlink path.

- [ ] **Step 1: Add five event registrations**

Merge into the existing `hooks` object (keep the `PreToolUse` dangerous-git entry untouched):

| Event | Command |
|---|---|
| `Notification` | `~/.claude/hooks/tmux-agent-flag.sh ask` |
| `Stop` | `~/.claude/hooks/tmux-agent-flag.sh done` |
| `UserPromptSubmit` | `~/.claude/hooks/tmux-agent-flag.sh clear` |
| `PostToolUse` (matcher `"*"`) | `~/.claude/hooks/tmux-agent-flag.sh clear` |
| `SessionEnd` | `~/.claude/hooks/tmux-agent-flag.sh clear` |

Each as `[{"hooks":[{"type":"command","command":"..."}]}]`; only `PostToolUse` takes a `matcher`. (`PostToolUse` is a builder addition beyond the spec's four events: it clears a granted-permission `✋` so the flag stays trustworthy — the spec's anti-goal.)

- [ ] **Step 2: Validate JSON**

Run: `python3 -c "import json;json.load(open('/Users/json0/.claude/settings.json'))" && echo OK` → expect `OK`.

- [ ] **Step 3: Stage and hand off commit**

```sh
git -C ~/Documents/workarea/local-config add settings.json
```
Give Jason: `git -C ~/Documents/workarea/local-config commit -m "feat: register tmux agent-waiting flag hooks"`.

### Task 3: Pill rendering (this repo)

**Files:**
- Modify: `tmux/tmux.conf:146-149` (window-status formats)

**Interfaces:**
- Consumes: window option `@claude_waiting` ∈ {`ask`, `done`, unset} from Task 1.

- [ ] **Step 1: Extend the two pill formats**

Define the flag segment once and append it inside each pill, before the trailing space. Inactive pill (on `bg=#3c3836`): `✋` in `#fe8019` for `ask`, `●` in `#a89984` for `done`. Current pill (on blue `#83a598`): same glyphs in `#282828`:

```tmux
set -g window-status-format         "#[fg=#928374,bg=#3c3836] #I #[fg=#a89984]#W#{?#{==:#{@claude_waiting},ask}, #[fg=#fe8019]✋,#{?#{==:#{@claude_waiting},done}, #[fg=#a89984]●,}} "
set -g window-status-current-format "#[fg=#282828,bg=#83a598,bold] #I #[fg=#1d2021]#W#{?#{==:#{@claude_waiting},ask}, #[fg=#282828]✋,#{?#{==:#{@claude_waiting},done}, #[fg=#282828]●,}} "
```

Add a comment line above noting the option is set by the Claude Code hook in `local-config/hooks/tmux-agent-flag.sh`.

- [ ] **Step 2: Verify format rendering on a scratch server**

```sh
tmux -L flagtest new-session -d -s t
tmux -L flagtest set -g window-status-format "<new format string>"
PANE=$(tmux -L flagtest display -p -t t '#{pane_id}')
tmux -L flagtest display -p -t "$PANE" '#{T:window-status-format}'   # unset: pill unchanged, no glyph
tmux -L flagtest set -w -t "$PANE" @claude_waiting ask
tmux -L flagtest display -p -t "$PANE" '#{T:window-status-format}'   # contains ✋
tmux -L flagtest set -w -t "$PANE" @claude_waiting done
tmux -L flagtest display -p -t "$PANE" '#{T:window-status-format}'   # contains ●
tmux -L flagtest kill-server
```
Expected: three outputs as commented; the unset case shows no stray commas/braces.

- [ ] **Step 3: Regenerate and hand off activation + commit**

Run `make hm` (export `PATH="/nix/var/nix/profiles/default/bin:$PATH"` first; don't pipe it — a trailing `tail` masks failures). Then stage:
```sh
git -C ~/Documents/workarea/dotfiles.nosync add tmux/tmux.conf docs/superpowers
```
Give Jason, for his terminal: the `git commit -m "feat: show agent-waiting flags in tmux window pills"`, plus `tmux kill-server` + reattach (also picks up today's uv-path fix), and an E2E check: start a Claude session in one window, trigger a permission prompt, switch windows, expect orange `✋` on that pill; approve it → glyph clears while Claude works; when it finishes → `●`; submit a new prompt → pill back to normal.
