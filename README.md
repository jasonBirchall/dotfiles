# Dotfiles

This repository contains both dotfile configuration and packages. The bits that are rather personal to my setup are as follows:

- Fedora host
- Nix + Home Manager
- Makefile-driven bootstrap
- Sway setup

---

Personal Fedora workstation configuration.

This repo manages:

- System packages (via `dnf`)
- User environment (via Nix + Home Manager)
- Sway configuration
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

The active profile is:

```
.#json0
```

---

# Dependencies

Before using this repo, you need:

- Fedora (Workstation or minimal install)
- `git`
- `make`
- `dnf`
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

1. Install system packages via `dnf`
2. Install Nix (if not present)
3. Clone or update the [private companion repo](#private-companion-repo) (`make local-sync`)
4. Apply Home Manager configuration

---

# Common Commands

Install system packages:

```bash
make dnf
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

Check for DNF drift (packages installed but not tracked):

```bash
make drift-dnf
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

# Design Principles

- Keep Fedora minimal.
- Move user tooling into Nix where possible.
- Avoid manual installs.
- Keep everything version controlled.
- Rebuildable from zero in one command.

---
