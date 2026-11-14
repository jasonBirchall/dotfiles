# Agent Counter and Desktop Notification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show on the tmux bar how many Claude agents are flagged in sessions that are not on screen, and raise a macOS notification when an agent becomes blocked while Jason isn't looking at its window.

**Architecture:** The counter is pure tmux format in `status-left`, reading the existing `@claude_waiting` window option, so it redraws on the option change with no polling. The notification is added to the existing hook script: its `ask` branch calls `terminal-notifier` unless the window is on screen and focused, and its `clear`/`done` branches withdraw it.

**Tech Stack:** tmux 3.8 formats, POSIX sh, terminal-notifier 3.1.0 (nixpkgs, darwin only), home-manager.

**Spec:** `docs/superpowers/specs/2026-11-14-agent-waiting-counter-and-notifications-design.md`

## Global Constraints

- No polling: no `#()` in the counter, no dependence on `status-interval`.
- The hook always exits 0 and never waits on the notifier (a non-zero `UserPromptSubmit` hook blocks the prompt; a slow one stalls every tool call).
- Notify on `ask` only. Never on `done`. No sound.
- Palette: orange `#fe8019` for `✋`, grey `#a89984` for `●`.
- Notification title is exactly `Claude needs you`; the body is the tmux window name.
- `local-config` has unrelated uncommitted work (`settings.json`, `skills/synced/`): edit only `hooks/tmux-agent-flag.sh` there. `settings.json` needs no change.
- `~/.claude/hooks` is a live symlink to `local-config/hooks`: the hook runs on every tool call of every Claude session, including the one doing this work. Develop on a copy; replace the real file only when its tests pass.
- Commits are YubiKey-signed: stage nothing, hand Jason the exact `git commit` commands. Conventional commits, no Co-Authored-By.
- `make hm` (activation) is Jason's step. Test against `home-manager build` output and nix store paths.
- Test tmux servers use their own socket (`tmux -L cfgcheck`) and are killed afterwards; never the live server.

## Review Focus

1. The notifier hangs (macOS permission dialog pending, notification centre busy): the hook must still return at once. Task 3, case 10.
2. Ghostty doesn't report focus to tmux, so "looking" is never true and every `ask` notifies: Task 1, step 2 checks the live client's `focused` flag in both states before the rule is relied on.
3. A window name with spaces, quotes or a leading `-`: it must reach the notifier as one argument and not be read as an option. Task 3, case 11.
4. The hook runs where `terminal-notifier` doesn't exist (Linux hosts, or before `make hm`): flag behaviour unchanged, exit 0. Task 3, case 8.
5. A `clear` arrives for a pane that was never notified (every `PostToolUse`): no notifier process is spawned. Task 3, case 7.

---

### Task 1: Feasibility checks on this Mac

**Files:** none changed.

**Interfaces:**
- Produces: `NOTIFIER` — the nix store path of the `terminal-notifier` binary, used by Task 3's real-notification step; and a yes/no on whether `-activate` and `-execute` can be combined.

- [ ] **Step 1: Build the notifier without installing it**

Run: `nix build --no-link --print-out-paths "<repo>#homeConfigurations.json0-darwin.pkgs.terminal-notifier"`
Expected: a store path containing `bin/terminal-notifier`.

- [ ] **Step 2: Confirm tmux sees Ghostty's focus**

Run `tmux list-clients -F '#{client_session} #{client_flags}'` a few times across the session.
Expected: `focused` present while Jason is typing in Ghostty, absent when he is in another app. If it is never present, stop and report: the "not looking" rule cannot work as designed.

- [ ] **Step 3: One real notification**

Run: `$NOTIFIER -title "Claude needs you" -message "test" -group claude-test -activate com.mitchellh.ghostty`, then `$NOTIFIER -remove claude-test`.
Expected: exit 0 from both. Jason confirms by eye that it appeared (macOS asks once for permission). If it cannot be made to appear, switch Task 3 to the spec's fallback (`osascript -e 'display notification …'`, no group, no removal) and say so.

- [ ] **Step 4: Check click-to-jump**

Run the same with `-execute "<abs tmux> switch-client -t <pane>"` added. If both actions fire on click, Task 3 includes `-execute`; otherwise it ships `-activate` only.

### Task 2: Counter on the bar (this repo)

**Files:**
- Modify: `tmux/tmux.conf` (the `status-left` block, currently `set -g status-left " "`)

**Interfaces:**
- Consumes: window option `@claude_waiting` = `ask` | `done` | unset (set by the hook).
- Produces: user options `@hidden_ask` and `@hidden_done`, each a format that expands to one `x` per matching window in sessions with `session_attached` = 0.

- [ ] **Step 1: Write the failing check**

`counter_check.py` (scratchpad, not committed): start `tmux -L cfgcheck -f <config under test>`, sessions `a` (attached through a pty), `b`, `c` (detached, `c` with two windows), `status-interval 0`. Assert on the text drawn to the attached client:

```
no flags                         -> bar contains neither ✋ nor ●
b:1 ask                          -> "✋1" within 1s
c:1 ask                          -> "✋2" within 1s
c:2 done                         -> "●1" within 1s
a:1 ask (the attached session)   -> still "✋2"
unset b:1 and c:1                -> "✋" gone, "●1" remains
```

- [ ] **Step 2: Run it against the installed config**

Run: `python3 -I counter_check.py ~/.config/tmux/tmux.conf`
Expected: FAIL at "b:1 ask" (no `✋1`).

- [ ] **Step 3: Implement in `tmux/tmux.conf`**

Define the two loops once and reference them, keeping the leading one-cell margin:

```
set -g @hidden_ask  "#{S:#{?session_attached,,#{W:#{?#{==:#{@claude_waiting},ask},x,}}}}"
set -g @hidden_done "#{S:#{?session_attached,,#{W:#{?#{==:#{@claude_waiting},done},x,}}}}"
set -g status-left " #{?#{n:#{E:@hidden_ask}},#[fg=#fe8019]✋#{n:#{E:@hidden_ask}} ,}#{?#{n:#{E:@hidden_done}},#[fg=#a89984]●#{n:#{E:@hidden_done}} ,}"
```

If `#{E:…}` does not expand under `#{n:…}` in tmux 3.8, inline the loops instead. Update the comment above the block to say what the counter means.

- [ ] **Step 4: Build and run the check against the build**

Run: `home-manager build --flake "<repo>#json0-darwin"` then `python3 -I counter_check.py result/home-files/.config/tmux/tmux.conf`
Expected: build exit 0, every assertion passes, tmux reports no config errors.

- [ ] **Step 5: Apply to the live server**

Set the three options on the live server with `tmux set -g`. Expected: `tmux show -gv status-left` equals the built config's value.

### Task 3: Notification in the hook (`local-config` repo)

**Files:**
- Modify: `~/Documents/workarea/local-config/hooks/tmux-agent-flag.sh`
- Modify: `modules/packages.nix` (this repo): add `terminal-notifier` to the `isDarwin` list.

**Interfaces:**
- Consumes: `$TMUX_PANE`, `$TMUX` (from the Claude process); `terminal-notifier` on PATH if installed.
- Produces: unchanged CLI `tmux-agent-flag.sh ask|done|clear`, always exit 0. Notification group id `claude-$TMUX_PANE`.

- [ ] **Step 1: Write the failing test**

`hook_check.py` (scratchpad): throwaway server with `focus-events on`, a pty-attached client, and a stub `terminal-notifier` first on PATH that appends its argv (one JSON list per call) to a log. Run the hook under test with `HOME` pointed at an empty dir (so the real profile is not on its PATH), `TMUX` pointing at the throwaway socket, `TMUX_PANE` set per case. Unfocus the client by writing `\033[O` to the pty, refocus with `\033[I`.

```
 1 ask, window active, client focused        -> flag=ask, no notifier call
 2 ask, client unfocused                     -> one call: -title "Claude needs you" -message <window name> -group claude-<pane> -activate com.mitchellh.ghostty
 3 ask, client focused, agent in a non-active window -> one call
 4 ask in a detached session                 -> one call
 5 clear after a notified ask                -> flag unset, one call: -remove claude-<pane>
 6 done after a notified ask                 -> flag=done, one call: -remove claude-<pane>
 7 clear with no flag set                    -> no notifier call
 8 ask with no terminal-notifier on PATH     -> flag=ask, exit 0
 9 ask with TMUX_PANE unset                  -> exit 0, no tmux change, no call
10 ask with a stub that sleeps 5s            -> hook returns in under 1s, exit 0
11 ask, window named `-x "two words"`        -> the -message value is exactly that string, one argv element
12 done with no prior ask                    -> flag=done, no notifier call
```

Every case also asserts exit status 0.

- [ ] **Step 2: Run it against the current hook**

Expected: cases 2–6, 10 and 11 FAIL (no notifier calls); 1, 7, 8, 9, 12 pass.

- [ ] **Step 3: Implement on a scratchpad copy of the hook**

Keep the header comment and the PATH line. `ask`: set the flag, then notify unless `#{window_active}` is 1 for `$TMUX_PANE` and some client attached to that pane's session has `focused` in `#{client_flags}`. `clear`/`done`: read the previous `@claude_waiting` first; withdraw the notification only when it was `ask`. Guard with `command -v terminal-notifier`. Run the notifier in the background with stdout/stderr discarded. Pass the body so a leading `-` is not parsed as an option. Add `-execute` only if Task 1 step 4 said yes.

- [ ] **Step 4: Run the test and shellcheck**

Run: `python3 -I hook_check.py <copy>` and `shellcheck <copy>`
Expected: 12/12 pass; shellcheck clean.

- [ ] **Step 5: Install the hook and add the package**

Copy the tested file over `local-config/hooks/tmux-agent-flag.sh` (keep mode 755). Add `terminal-notifier` to the darwin list in `modules/packages.nix`; `home-manager build` exits 0 and `result/home-path/bin/terminal-notifier` exists.

- [ ] **Step 6: Real end-to-end check**

With `$NOTIFIER`'s directory on PATH, run the installed hook `ask` against a real pane in a detached live session, then `clear`. Expected: `✋1` on the bar and a notification, both gone after `clear`. Jason confirms by eye.

### Task 4: Hand-off

- [ ] **Step 1: Give Jason the activation and commit commands**

`make hm` (installs terminal-notifier and the bar change), then:

```
git -C ~/Documents/workarea/local-config add hooks/tmux-agent-flag.sh && git -C ~/Documents/workarea/local-config commit -m "feat: desktop notification when an agent is blocked"
git add modules/packages.nix tmux/tmux.conf docs/superpowers && git commit -m "feat: off-screen agent counter and terminal-notifier"
```

Note that the second commit also carries the session's earlier `tmux.conf` changes unless he splits them.
