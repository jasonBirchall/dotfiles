# Dotfiles

This repository contains both dotfile configuration and packages. The bits that are rather personal to my setup are as follows:

- Fedora, Ubuntu and macOS (Apple silicon) hosts
- Nix + Home Manager
- Makefile-driven bootstrap
- Sway setup (Linux)

---

Personal workstation configuration — Fedora and Ubuntu on Linux, macOS on a MacBook Pro M1. Every host gets the same two-layer split and the same Makefile; only the system layer's package manager changes.

This repo manages:

- System packages (via `dnf`, `apt` or Homebrew, per host)
- User environment (via Nix + Home Manager)
- Sway configuration
- GNOME + pop-shell keybindings (mirroring sway, for GNOME sessions)
- A GNOME Shell extension of its own, `gnome/top-consumer@jsond`, putting the
  top CPU or memory process in the panel
- Waybar, mako, swaylock styling
- Shell configuration

The goal is **reproducible workstation builds**.

---

## Architecture

The machine is split into two layers:

### 1. Fedora (system layer)

Managed with `dnf`.

Includes:

- Sway compositor
- Waybar
- Mako
- Swaylock / swayidle
- Fonts
- Hardware / system utilities

System packages are listed in:

```
fedora/system-packages.txt
```

---

### 1b. macOS (system layer)

Managed with Homebrew. GUI apps (casks), fonts and mac-only tools live in:

```
mac/Brewfile
```

CLI tooling comes from the Nix layer below, exactly as on Linux — the
Brewfile deliberately holds nothing Home Manager can provide. `make
drift-system` reports anything installed outside it. (Apple's own App Store
apps are kept installed but untracked; the drift target knows not to judge
them.)

---

### 2. Nix (user layer)

Managed with:

- Flakes
- Home Manager

Includes:

- CLI tools
- Development tooling
- Shell configuration
- Neovim
- Dotfile symlinks
- User-level config

The flake keys profiles by `<username>-<distro>`; the Makefile picks the
right one automatically (`.#json0-fedora`, `.#jsond-ubuntu`,
`.#json0-darwin`, …).

---

# Dependencies

Before using this repo, you need:

- Fedora (Workstation or minimal install), Ubuntu, or macOS
- `git`
- `make`
- The platform's package manager: `dnf`/`apt` come with the distro; on
  macOS install [Homebrew](https://brew.sh) and the Xcode command line
  tools (`xcode-select --install`) first
- Internet access

Nix will be installed automatically by the bootstrap target if missing.

---

## Bootstrap a New Machine

Clone the repo:

```bash
git clone <your-repo-url>
cd dotfiles
```

Run:

```bash
make bootstrap
```

This will:

1. Install system packages via `dnf`/`apt`/`brew bundle`, per host
2. Install Nix (if not present)
3. Clone or update the [private companion repo](#private-companion-repo) (`make local-sync`)
4. Apply Home Manager configuration

The same command works on macOS; its dependency chain is just shorter.
The Linux tail (suricata, auditd, pop-shell, xremap, …) doesn't apply —
Tailscale and the GUI apps arrive as casks from `mac/Brewfile` instead.

---

## Post-bootstrap manual steps

`make bootstrap` installs every package and config, but a handful of things can't be automated: interactive logins and device pairings. A rebuilt machine has the tools but not the sessions — this is the "why am I logged out?" list. Do these once per machine:

- **Proton Drive** — `proton-drive auth login` opens a browser to sign in; the session is then cached in libsecret, so you won't be asked again. After that the `pdrive` wrapper (and its `pd` alias) work. How the binary is pinned and updated lives in `modules/services.nix`; `make audit` tells you when a newer release ships.
- **Signal** — launch Signal, then on your phone go to *Settings → Linked devices → Link new device* and scan the QR code. History doesn't backfill; both devices sync forward from the link point. Same dance on macOS.
- **YubiKey (macOS)** — run `~/bin/yubikey-ssh-bootstrap` with the key
  plugged in to export the resident key handle (PIN + touch). Commit
  signing then needs the key passphrase + touch per commit; load the key
  into an sk-capable ssh-agent (`ssh-add ~/.ssh/id_ed25519_sk_rk`, using
  the nix openssh — Apple's agent can't hold FIDO2 keys) to reduce that
  to touch-only and to let non-TTY tools (IDEs, agents) sign.

---

# Common Commands

Install system packages (dnf, apt or brew bundle — detected per host):

```bash
make system
```

Apply Home Manager config:

```bash
make hm
```

Sync the private companion repo:

```bash
make local-sync
```

Full rebuild:

```bash
make bootstrap
```

Check for system-package drift (installed but not tracked):

```bash
make drift-system
```

---

# Sway Keybinds

`Mod` is the Super (Windows) key. The full keybinding list lives in `sway/config`; the bindings below are the ones worth knowing before you've logged in for the first time. Inside a running Sway session, `Mod + /` opens a searchable cheatsheet of every binding (sourced live from the config file).

### Session

| Keys | Action |
| --- | --- |
| `Mod + Shift + r` | Reload Sway config |
| `Mod + Shift + q` | Lock screen |
| `Mod + Shift + s` | Lock, then suspend |
| `Mod + Shift + e` | Exit Sway (back to greeter) |
| `Mod + Shift + End` | Power menu (lock / suspend / hibernate / logout / reboot / shutdown) |
| `Mod + /` | Cheatsheet of all keybinds |

### Apps & windows

| Keys | Action |
| --- | --- |
| `Mod + Return` | Open terminal |
| `Mod + d` | Application launcher (wofi) |
| `Mod + q` | Close focused window |
| `Mod + f` | Fullscreen toggle |
| `Mod + {h,j,k,l}` | Focus left / down / up / right |
| `Mod + Shift + {h,j,k,l}` | Move window left / down / up / right |
| `Mod + r` | Enter resize mode — then `hjkl` to resize, `Esc` to exit |
| `Mod + {1..4}` | Switch to workspace 1–4 |

### Screenshots

| Keys | Action |
| --- | --- |
| `Print` | Area select → clipboard |
| `Shift + Print` | Full screen → clipboard |
| `Mod + Print` | Area select → `~/Pictures/screenshots/` |

### Audio & media

Dedicated keys (`XF86AudioRaiseVolume`, `XF86AudioPlay`, etc.) work where the keyboard has them. For keyboards that don't, `Mod + PageUp/PageDown/End` cover volume and mute.

---

# Configuration Locations

| Component       | Location                      |
| --------------- | ----------------------------- |
| Sway            | `sway/config`                 |
| Waybar          | `waybar/config` + `style.css` |
| Mako            | `mako/config`                 |
| Swaylock        | `~/.config/swaylock/config`   |
| System packages | `fedora/system-packages.txt`  |

---

# Private companion repo

A few configuration files live outside this repo because they're personal enough that I don't open-source them. They sit in a private sibling repo at `~/Documents/workarea/local-config/`, fetched and kept in sync by:

```bash
make local-sync
```

This target runs as part of `make bootstrap` ahead of Home Manager, because `home.nix` references files inside `local-config/` — the clone has to land first.

If you've cloned this repo without access to the private companion, `make hm` and `make bootstrap` will fail at the `local-sync` step. Comment out the lines that reference `local-config/` in `home.nix` to skip the private parts, or run the individual targets that don't depend on `local-sync` directly.

---

# Gotchas

Things that have cost me a head-scratch, written down so they cost less next time.

- **The Proton Drive CLI skips Docs and Sheets.** `pdrive pull` (and the underlying `proton-drive filesystem download`) quietly skip anything stored as a Proton Doc or Sheet — those live in Proton's editor in a proprietary format, not as real files. So a pull of a folder that holds only Docs finishes cleanly and downloads *nothing*, which looks broken but isn't. To get a Doc locally, export it from the Proton Docs web UI first. Regular files (PDFs, images, `.md`, …) come down fine.
- **Commit signing needs a TTY (or an agent).** The signing key file is
  passphrase-protected; anything without a terminal (IDE commit buttons,
  AI agents, cron) fails with "incorrect passphrase supplied to decrypt
  private key". Fix: `ssh-add ~/.ssh/id_ed25519_sk_rk` once per login, or
  commit from a real terminal.
- **A short YubiKey touch types gibberish.** That's the OTP slot firing,
  not a bug — the FIDO2 touch only reads when ssh/ssh-keygen is actually
  waiting on the key.

---

# Design Principles

- Keep Fedora minimal.
- Move user tooling into Nix where possible.
- Avoid manual installs.
- Keep everything version controlled.
- Rebuildable from zero in one command.

---
