#!/usr/bin/env bash
# Validate the flatpak app IDs tracked in common/flatpaks.txt.
#
# Two failure modes, and without this both stay invisible until `make flatpak`
# runs on a fresh machine — the worst moment to find them, since bootstrap is
# the one thing that has to work from zero:
#
#   1. The ID does not exist. App IDs are case-sensitive, the casing is not
#      consistent between projects, and `flatpak search` lowercases everything
#      it prints, so an ID copied out of a search is easy to get subtly wrong.
#
#   2. The ID exists but is end-of-life. This is the nastier one, because
#      nothing fails. Flathub keeps EOL refs resolvable and tags them with an
#      End-of-life-rebase pointing at the replacement, so `flatpak install`
#      succeeds and quietly installs the app under a *different* ID than the
#      one written down. `make drift-flatpak` then reports the replacement as
#      untracked drift on every run, which reads as noise rather than as the
#      signal it actually is. org.mozilla.Thunderbird did exactly this: it
#      rebased to org.mozilla.thunderbird_esr in 2026-05.
#
# Needs the network. Every other pre-commit hook in this repo works offline, so
# this one skips rather than fails when the remote is unreachable — a hook that
# blocks a commit on a train just gets --no-verify'd, and a hook that is
# routinely bypassed is worth less than no hook at all.
set -euo pipefail

# Both lookups are wrapped in `timeout`. An unreachable remote does not fail
# fast — a blackholed route leaves flatpak waiting on a TCP connect for minutes,
# and a hook that hangs a commit is worse than one that fails it. Erring short is
# safe in both directions: a premature timeout only downgrades this to the skip
# it would have taken anyway, and never reports a healthy ID as broken.
PROBE_TIMEOUT=15
LOOKUP_TIMEOUT=20

files=("$@")
if [ ${#files[@]} -eq 0 ]; then
  files=(common/flatpaks.txt)
fi

status=0

# Memoised per remote: 0 reachable, 1 not. Probed with one remote-ls, whose
# summary flatpak then caches, so the per-ID lookups below cost nothing extra.
declare -A remote_reachable=()

# Configured remotes, read once. Checked separately from reachability so a
# typo'd remote name is an error rather than being waved through as "offline" —
# otherwise 'flathubb' would skip every ID under it and the hook would pass.
configured_remotes=$(flatpak remotes --columns=name 2>/dev/null || true)

remote_is_configured() {
  printf '%s\n' "$configured_remotes" | grep -qxF "$1"
}

remote_is_reachable() {
  local remote=$1
  if [ -z "${remote_reachable[$remote]+set}" ]; then
    if timeout "$PROBE_TIMEOUT" flatpak remote-ls "$remote" --app --columns=application >/dev/null 2>&1; then
      remote_reachable[$remote]=0
    else
      remote_reachable[$remote]=1
    fi
  fi
  return "${remote_reachable[$remote]}"
}

for file in "${files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "check-flatpaks: no such file: $file" >&2
    status=1
    continue
  fi

  while read -r remote app extra; do
    # Guard the format before spending a network call on a malformed line.
    if [ -z "$app" ] || [ -n "$extra" ]; then
      echo "  malformed line (want '<remote> <app-id>'): $remote $app $extra" >&2
      status=1
      continue
    fi

    if ! remote_is_configured "$remote"; then
      echo "  remote not configured: '$remote' (line: $remote $app)" >&2
      echo "      configured remotes: $(printf '%s' "$configured_remotes" | tr '\n' ' ')" >&2
      status=1
      continue
    fi

    if ! remote_is_reachable "$remote"; then
      echo "  skipping: remote '$remote' unreachable (offline?)" >&2
      continue
    fi

    # Piped, so flatpak writes untruncated output rather than eliding the
    # rebase target to fit a terminal width.
    rc=0
    info=$(timeout "$LOOKUP_TIMEOUT" flatpak remote-info "$remote" "$app" 2>&1 | cat) || rc=$?

    # Separated from the failure below on purpose: a timeout means the lookup
    # never happened, so calling the ID missing would be a lie that fails the
    # commit for a bad connection.
    if [ "$rc" -eq 124 ]; then
      echo "  skipping: lookup of '$app' timed out after ${LOOKUP_TIMEOUT}s" >&2
      continue
    fi

    if [ "$rc" -ne 0 ]; then
      echo "  not found on '$remote': $app" >&2
      echo "      IDs are case-sensitive; confirm with 'flatpak remote-info $remote <id>'" >&2
      status=1
      continue
    fi

    if rebase=$(printf '%s\n' "$info" | sed -n 's|^ *End-of-life-rebase: *app/\([^/]*\)/.*|\1|p') &&
      [ -n "$rebase" ]; then
      echo "  end-of-life: $app" >&2
      echo "      Flathub has rebased it to '$rebase'. Installing $app still" >&2
      echo "      succeeds but lands $rebase, so this line and the installed" >&2
      echo "      app disagree and 'make drift-flatpak' reports it forever." >&2
      echo "      Fix: replace this line with '$remote $rebase'." >&2
      status=1
      continue
    fi

    # EOL without a rebase target: retired outright, no replacement named.
    if printf '%s\n' "$info" | grep -q '^ *End-of-life:'; then
      echo "  end-of-life (no replacement named): $app" >&2
      printf '%s\n' "$info" | sed -n 's|^ *End-of-life: *|      upstream says: |p' >&2
      status=1
      continue
    fi
  done < <(grep -vE '^\s*#|^\s*$' "$file")
done

exit "$status"
