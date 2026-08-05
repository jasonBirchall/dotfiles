#!/usr/bin/env bash
# Install pop-shell on Ubuntu.
#
# Fedora installs pop-shell from the distro repos (see fedora/system-packages.txt),
# but Debian/Ubuntu don't package it, so we build from source. Two things matter:
#
#   1. The branch. pop-os/shell's default branch (master_noble) declares
#      shell-version 45-50; the long-lived 'master' is pinned at GNOME 41 and
#      will install cleanly but never load. We follow the repo default rather
#      than hard-coding a branch, so this tracks upstream as it moves.
#   2. `make local-install` targets ~/.local/share/gnome-shell/extensions,
#      which is user-level. Nothing after the dependency install needs root,
#      and it can't collide with anything home-manager owns.
#
# Enabling the extension is modules/gnome.nix's job (dconf enabled-extensions),
# as are the keybindings. This script only puts the files in place.
# Idempotent: safe to re-run — the work branch is recreated from upstream on
# every run, so the cherry-picks below re-apply cleanly rather than stacking up.
set -euo pipefail

SRC_DIR="${POP_SHELL_SRC:-$HOME/Documents/workarea/pop-shell}"
UUID="pop-shell@system76.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"

# Upstream commits applied on top of the default branch, newest concern first.
# Each is a fix that exists upstream but has not been merged to the default
# branch yet. Remove an entry once it lands — the script tells you when one has
# become redundant rather than failing on an empty cherry-pick.
#
#   08227c5  "src: Fix (un)maximize usage for GNOME 49."
#            Meta.Window.unmaximize() lost its flags argument in GNOME 49
#            (mutter!4415) and master_noble still passes one. Two of the seven
#            call sites are in the focus handler, so every focus change where
#            the previous window was maximized or stacked leaves a stale
#            maximize state behind; mutter then logs
#            "meta_window_set_stack_position_no_sync: assertion
#            'window->stack_position >= 0' failed" and focus lands on a window
#            you cannot see, with pop-shell's active hint drawn around it.
#            Upstream issue #1801, fixed by PR #1821, unmerged as of 2026-07.
PATCHES=(
  08227c5acbca4fc64b3a655670cfa67b5599b1ad
)

# Branch we build from. Never checked out by hand — it is force-recreated from
# the upstream default on each run, so anything committed here is disposable.
WORK_BRANCH="dotfiles-pinned"

# node-typescript provides tsc; gnome-shell-extension-prefs hosts the prefs UI.
# make is already supplied by Nix (modules/packages.nix) but apt's is harmless.
echo "[*] Installing build dependencies..."
sudo apt install -y git node-typescript gnome-shell-extension-prefs

if [ -d "$SRC_DIR/.git" ]; then
  echo "[*] Fetching upstream into existing checkout at $SRC_DIR"
  git -C "$SRC_DIR" fetch --quiet origin
else
  echo "[*] Cloning pop-os/shell into $SRC_DIR"
  git clone --quiet https://github.com/pop-os/shell.git "$SRC_DIR"
fi

# Refuse to clobber uncommitted work rather than silently discarding it.
if [ -n "$(git -C "$SRC_DIR" status --porcelain)" ]; then
  echo "    ERROR: $SRC_DIR has uncommitted changes." >&2
  echo "    This script recreates '$WORK_BRANCH' from upstream, which would" >&2
  echo "    discard them. Commit, stash or remove them and re-run." >&2
  exit 1
fi

# Whatever upstream currently calls its default branch, rather than a hard-coded
# name — master_noble today, something else after the next Ubuntu LTS.
default_branch="$(git -C "$SRC_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
default_branch="${default_branch:-master_noble}"

echo "[*] Building from upstream default branch: $default_branch"
git -C "$SRC_DIR" checkout --quiet -B "$WORK_BRANCH" "origin/$default_branch"

# Commit signing is disabled for these picks on purpose. The user's global
# gitconfig signs commits with a resident YubiKey key, and a build tree of
# somebody else's project is not something that benefits from a signature —
# but an absent YubiKey would abort the cherry-pick with "device not found"
# and leave the checkout mid-pick.
for sha in "${PATCHES[@]}"; do
  subject="$(git -C "$SRC_DIR" log -1 --format=%s "$sha" 2>/dev/null || echo "$sha")"
  if git -C "$SRC_DIR" merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
    echo "    already upstream, skipping: $subject"
    echo "    (drop ${sha:0:7} from PATCHES in this script)"
    continue
  fi
  echo "    cherry-picking ${sha:0:7}: $subject"
  if ! git -C "$SRC_DIR" -c commit.gpgsign=false cherry-pick "$sha"; then
    echo "    ERROR: cherry-pick of ${sha:0:7} failed — it probably conflicts" >&2
    echo "    with upstream movement. Check whether it has been merged and can" >&2
    echo "    be dropped from PATCHES. Aborting the pick to leave the tree clean." >&2
    git -C "$SRC_DIR" cherry-pick --abort || true
    exit 1
  fi
done

# Guard the failure mode that costs the most time to diagnose: a clean build
# and install of an extension the running shell will refuse to load.
supported="$(tr -d ' \n' <"$SRC_DIR/metadata.json" |
  sed -n 's/.*"shell-version":\[\([^]]*\)\].*/\1/p' | tr -d '"')"
running="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
if [ -n "$running" ] && [ -n "$supported" ]; then
  if printf '%s' ",$supported," | grep -q ",$running,"; then
    echo "[*] GNOME $running is supported ($default_branch declares: $supported)"
  else
    echo "    WARNING: running GNOME $running, but $default_branch declares" >&2
    echo "    support for: $supported. The extension will install but may not" >&2
    echo "    load. Upstream has usually opened a testing branch for the new" >&2
    echo "    GNOME by this point — check pop-os/shell's branches and, if there" >&2
    echo "    is one, add its commits to PATCHES above rather than switching" >&2
    echo "    the whole build onto an unmerged branch." >&2
  fi
fi

make -C "$SRC_DIR" local-install

echo ""
echo "[*] pop-shell installed to $EXT_DIR"
echo ""
echo "    GNOME cannot reload extensions on Wayland, so log out and back in to"
echo "    activate it. Keybindings are applied by modules/gnome.nix."
echo ""
