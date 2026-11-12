# Darwin support: same strategies, new platform

**Date:** 2026-11-12
**Target machine:** MacBook Pro M1 (`json0`, arm64, macOS)
**Goal:** `main` becomes cross-platform. The Mac uses the same two-layer
strategy as the Linux hosts — a system package layer (Homebrew, playing the
dnf/apt role) and a user layer (standalone Home Manager via the existing
flake) — driven by the same Makefile. The legacy `mac-m1` branch (dotbot +
Brewfile) is retired.

## Decisions made

| Question | Decision |
| --- | --- |
| Nix depth | Standalone Home Manager + Homebrew. No nix-darwin. |
| Branching | `main` gains Darwin support via a feature branch; `mac-m1` retired after salvage. |
| Old Brewfile | Not carried forward. Fresh minimal `mac/Brewfile` (casks/GUI only). |
| Karabiner / iTerm configs | Not salvaged. Ghostty is the terminal. |
| local-config (private repo) | Synced on the Mac too; `~/.claude` symlinks apply. |
| Shell | zsh stays on the Mac. HM gains a Darwin-only `programs.zsh` mirroring the bash setup. |
| Cleanup scope | All of: dotbot-era symlinks, brew prune, stale git branches. |

## 1. Nix architecture

Approach: flake-level platform injection. The alternative — guarding inside
every module — fails because `systemd.user.*` options do not exist in Home
Manager on Darwin, so `services.nix` errors at import time no matter what
`mkIf` wraps its contents. Module inclusion itself must be conditional.

### flake.nix

- `mkHome` gains `system ? "x86_64-linux"`; nixpkgs is imported per-system.
- `homeDirectory` derived from platform: `/Users/<user>` on Darwin, else
  `/home/<user>`.
- The existing `distro` module arg gains a `"darwin"` value — no new concept;
  modules already branch on `distro`.
- Linux-only modules (`services.nix`, `gnome.nix`) move out of `home.nix`
  into a conditional list appended by `mkHome` when the platform is Linux.
- New module arg `dotfilesDir`, injected per-host. Default
  `~/Documents/workarea/dotfiles`; this Mac overrides to
  `~/Documents/workarea/dotfiles.nosync` (iCloud-avoidance suffix).
- New entry: `"json0-darwin" = mkHome "json0" { system = "aarch64-darwin"; distro = "darwin"; }`.

### Modules

- **packages.nix** — Linux-only tools wrapped in
  `lib.optionals stdenv.isLinux`: `wl-clipboard`, `xclip`, `playerctl`,
  `wev`, `wl-kbptr`, `wlrctl`, `pop-launcher`, `xremap`, `nethogs`, `gcc`.
  Darwin additionally gets nixpkgs `openssh`: Apple ships ssh without
  FIDO2/sk support, and the YubiKey resident key needs it.
- **shell.nix** — bash config unchanged. Adds Darwin-only `programs.zsh`
  with the same aliases plus zsh integration for fzf/zoxide/direnv.
  The auditd/suricata aliases and the `SSH_AUTH_SOCK`/`XDG_RUNTIME_DIR`
  override become Linux-only (macOS keeps its launchd agent socket).
  The `cdd` alias uses `dotfilesDir`.
- **dotfiles.nix** — uses `dotfilesDir` for out-of-store symlinks.
  Linux-only links guarded: sway, gnome, waybar, wofi, mako, swaylock,
  xremap, lnav auditd format, flatpak override, suricata scripts,
  `diagnosis.sh`, `camera-relay.sh`. Shared links: nvim, ranger, lazygit,
  ghostty, newsboat, `~/.claude` → local-config, `yubikey-ssh-bootstrap`,
  `pdrive`, `view.py`, `connection-checker.py`.
- **ssh.nix** — shared unchanged (already written host-agnostic; YubiKey
  SSH + git signing identical on the Mac).
- **tmux.nix** — shared. Implementation must verify `bin/battery-remain.sh`
  (reads Linux `/sys`); the Darwin status line falls back to tmux-battery's
  native `#{battery_remain}` if the script cannot work there.

## 2. Makefile, Brewfile, bootstrap

- **common/detect-distro.sh** answers `darwin` when `uname -s` is Darwin
  (currently reads only `/etc/os-release`). `FLAKE` then resolves to
  `.#json0-darwin` with no further changes.
- **mac/Brewfile** (new) — the Darwin analogue of
  `fedora/system-packages.txt`: casks/GUI apps and mac-only tools, nothing
  Home Manager provides. Seeded from currently-installed casks minus stale
  ones; exact keep/remove list approved by the user during implementation
  (see §3.2).
- **Makefile darwin branches:**
  - `make system` → `brew bundle --file mac/Brewfile` (new
    `darwin-packages` target, dispatched like `fedora-packages`).
  - `make flatpak` → polite no-op on darwin (bootstrap prerequisite, must
    not error — same convention as the `suricata` target on Ubuntu).
  - `make nix` → unchanged; Determinate installer handles macOS.
  - `make bootstrap` → per-distro dependency list. Darwin:
    `system flatpak nix local-sync hm lint-install`. The Linux-only tail
    (suricata, auditd, pop-shell, xremap, tailscale, firefox-nightly) is
    dropped; Tailscale arrives as a cask instead.
  - `make update` → darwin: `brew update && brew upgrade && brew bundle`
    replaces apt/dnf; flatpak step skipped; flake update +
    `home-manager switch` + `uv tool upgrade` shared.
  - `make audit` → darwin: `brew outdated` + flake input age.
  - `make drift-system` → darwin: `brew bundle cleanup --dry-run` (lists
    installed-but-untracked — drift detection for free).
  - Linux-only targets follow existing conventions: error on darwin when
    reaching them means the request is wrong (`nvidia`, `camera`,
    `displaylink`, `vpn`, `xremap`); no-op when they are bootstrap
    prerequisites (`suricata`, `auditd`).
- **README** — macOS section: darwin column in the two-layer architecture,
  bootstrap instructions, post-bootstrap manual steps (YubiKey bootstrap,
  Signal link).

## 3. Cleanup

### 3.1 Dotbot-era symlinks on this Mac

Removed **before** the first `make hm` (HM refuses to clobber files it does
not own): `~/.zshrc`, `~/.zshenv`, `~/.config/.zshenv`, `~/.tmux.conf`,
`~/.ideavimrc` (dangling), `~/.gitconfig`, `~/.newsboat`, `~/.config/nvim`,
`~/.config/ranger`. HM recreates what matters; git identity/signing comes
from `programs.git` in `ssh.nix`, not the old `git/gitconfig` symlink.

### 3.2 Brew prune (usage-informed)

Only the ~93 `brew leaves` (top-level installs) are judged; `brew
autoremove` sweeps orphaned dependencies afterwards. Usage signals:

- **Casks:** Spotlight last-opened date —
  `mdls -name kMDItemLastUsedDate /Applications/<app>.app`. Verified
  working on this machine (e.g. Warp last opened 2023-01-01 → remove;
  Ghostty today → keep).
- **Formulae:** binary last-access time (`stat -f '%Sa'`), cross-checked
  against what Home Manager now provides. Shell history is not a usable
  signal here — `~/.zsh_history` has been stale since 2022 because the
  dangling zshrc never configured history persistence.

Flow: analysis produces a keep/remove table → user approves → kept items
land in `mac/Brewfile` → `brew bundle cleanup --file mac/Brewfile` removes
the rest → `brew autoremove`. The Brewfile is the single source of truth
from day one.

### 3.3 Repo cleanup

- Delete dead local branches (`0a`, `convert-lua`, `fedora`, `merge-lua`)
  and stale remote branches (`convert-lua`, `fedora`, `laptop`, `master`,
  `merge-lua`, `remove/jdk`, `ubuntu-support`) — each verified merged/dead
  and the list shown to the user before any deletion on origin.
- Switch the GitHub default branch from `mac-m1` to `main`, tag the branch
  tip as `archive/mac-m1`, then delete the branch — the old dotbot-era tree
  stays reachable forever without cluttering the branch list.
- Remove legacy dirs on `main` that only served the old setups
  (e.g. `zsh/packages` submodules) if nothing references them — checked,
  not assumed.

## 4. Migration order

1. Feature branch off `main`; implement flake/module/Makefile changes.
2. `make nix` → `make local-sync` → remove old symlinks (§3.1) →
   `make hm`. Verify: zsh aliases/fzf/zoxide, nvim, tmux, git signing,
   `ssh -T git@github.com` with YubiKey.
3. Brew usage analysis → approved keep/remove list → write `mac/Brewfile`
   → prune (§3.2).
4. Merge to `main`; repo cleanup (§3.3).
5. Post-bootstrap manual steps: `~/bin/yubikey-ssh-bootstrap` with the key
   plugged in; Signal device link; README gotchas updated as found.

## Error handling & testing

- `nix flake check` / `home-manager build --flake .#json0-darwin` must pass
  before any `switch`; Linux attributes must still evaluate
  (`nix eval` of `json0-fedora`, `jsond-ubuntu` activation packages) so the
  Mac work cannot break the Linux hosts.
- `make hm` on a host whose distro is unknown still errors loudly rather
  than guessing (existing behaviour, now with darwin as a known value).
- Brew prune happens only after `make hm` has proven the HM layer works —
  the machine is never left without a working editor/shell mid-migration.
