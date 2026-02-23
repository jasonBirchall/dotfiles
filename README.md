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
3. Apply Home Manager configuration

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

- `Mod + Shift + r` — Reload Sway
- `Mod + Shift + x` — Lock screen
- `Mod + Shift + s` — Lock and suspend

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

# Design Principles

- Keep Fedora minimal.
- Move user tooling into Nix where possible.
- Avoid manual installs.
- Keep everything version controlled.
- Rebuildable from zero in one command.

---
