# Agents I can't see: a bar counter and a desktop notification

**Date:** 2026-11-14 · **Status:** approved

## Intent

The ✋/● flags on the window pills only help for the session I'm attached
to. Today I had three sessions and one bar, so an agent blocked in session
`0` was invisible from session `6`. And when I'm in the browser, nothing
tells me at all. I want to know an agent is stuck on me wherever I am,
without the bar or my notification centre turning into noise.

This extends the 2026-11-12 flags design. That one listed desktop
notifications as a non-goal; this one reverses that, on purpose.

## Goals

- The bar shows how many agents are flagged in sessions that are not on
  screen: orange `✋2` for blocked, grey `●1` for finished. Nothing when
  the count is zero.
- A macOS notification when an agent becomes blocked (`ask`) and I'm not
  looking at its window. It names the project, e.g. "dotfiles".
- The notification goes away when the flag clears, so a stale one never
  sits in notification centre claiming something still needs me.
- Same trust level as the flags: driven by the hook, never by guessing.

## Non-goals

- Notifying when an agent merely finishes (`done`). That stays on the bar.
- Linux notifications. The hook is shared with the Fedora and Ubuntu
  hosts; there it keeps doing what it does today and skips the rest.
- Sound.

## Anti-goals

- Polling. No `#()` script, no `status-interval` dependency.
- A notification for the window I'm already looking at.
- A hook that can block or slow Claude. It stays fast and always exits 0.

## Constraints

- Two repos. The counter is `tmux/tmux.conf` here; the notification is
  `hooks/tmux-agent-flag.sh` in `local-config`, which has unrelated
  uncommitted work in it (`settings.json`, `skills/synced/`) that must not
  be touched. `settings.json` needs no change: the `ask` event is already
  wired.
- Commits need my terminal (YubiKey).

## Approaches considered

**Counter**

1. **tmux formats only** (picked). `#{S:…}` and `#{W:…}` loop over
   sessions and windows, `#{n:…}` turns the matches into a number. Tested
   in a throwaway server with `status-interval 0`: setting the flag in a
   detached session redrew the attached client's bar in about 0.1s. So it
   is event-driven for free.
2. A `#()` script in the status line. Polls every 10s; rejected by the
   no-polling anti-goal.
3. The hook maintains a global count. More state to go stale when an
   agent is hard-killed; rejected.

**Notification**

1. **The existing hook calls `terminal-notifier`** (picked). 3.1.0 is in
   the pinned nixpkgs for aarch64-darwin. It can replace and remove
   notifications by group, and bring Ghostty forward on click.
2. `osascript -e 'display notification'`. No package, but the
   notification belongs to Script Editor, clicking it opens Script Editor,
   and it can't be withdrawn. This is the fallback if (1) misbehaves.
3. Ghostty's own notification escape sequence through tmux. Needs
   `allow-passthrough` on and an attached client; rejected as fragile.
4. tmux `monitor-silence`. Silence is a guess, and guessing is what the
   flags design rejected the bell for.

## Design

**Counter** — `status-left` in `tmux/tmux.conf` keeps its one-cell margin
and gains two conditional segments. Each counts windows whose
`@claude_waiting` is `ask` (or `done`) in sessions with no attached
client. A session attached in another terminal window counts as on
screen.

**Notification** — in the hook's `ask` branch, after setting the flag:

- Skip if the agent's window is the active window of a session that has a
  focused client. (tmux learns focus from Ghostty; `focus-events` is
  already on.) Otherwise notify.
- Title "Claude needs you", body the window name (the folder). Grouped
  per pane, so a repeat replaces the previous one rather than stacking.
- Run in the background; any failure is swallowed.

In the `clear` and `done` branches, remove that pane's notification.

`terminal-notifier` is added to `modules/packages.nix` for darwin only.
The hook already puts `~/.nix-profile/bin` on its PATH. If the binary is
missing, the hook skips the notification silently.

## Accepted edges

- macOS asks once to allow notifications from terminal-notifier. Until I
  say yes, nothing appears.
- Focus / Do Not Disturb suppresses them. That's the point of Focus.
- If I'm in another tmux window with Ghostty focused, I get the
  notification *and* see the ✋ on the pill. Option A as agreed.
- The flags design's edges carry over: two agents in one window share a
  flag, and a hard-killed agent can leave a stale one.

## Open, to settle while building

- I haven't run terminal-notifier on this macOS. First step is one real
  notification on screen; if it doesn't show, switch to the fallback.
- Clicking should bring Ghostty forward. Jumping straight to the agent's
  window on click would be better; do it if terminal-notifier allows both
  at once, otherwise leave it.

## Testing

- Counter: throwaway tmux server with a real attached client, as in the
  feasibility test. Flag in a detached session appears; flag in the
  attached session doesn't; zero shows nothing.
- Hook: run the script against a throwaway server with a stub
  `terminal-notifier` on PATH that records its arguments. Cases: blocked
  and not looking notifies; blocked and looking doesn't; `clear` and
  `done` remove; missing binary and no `$TMUX_PANE` exit 0 quietly.
- Then one real notification, confirmed by eye.
