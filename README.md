# Dotfiles

This is how my workstations get built: a couple of Fedora and Ubuntu laptops and an M1 MacBook Pro, from one repo and one command.

```bash
git clone <your-repo-url>
cd dotfiles
make bootstrap
```

It's personal (Sway, Nix + Home Manager, a YubiKey, tmux with everything in gruvbox), so I don't expect anyone to run it as it is. What might travel is the set of rules it follows. I've written the README around those, with the mechanics hanging off each one, and a plain [reference](#reference) at the bottom for when I just want the command.

## The principles

1. [A new machine is one command away](#1-a-new-machine-is-one-command-away)
2. [The distro gets the minimum, Nix gets the rest](#2-the-distro-gets-the-minimum-nix-gets-the-rest)
3. [If it's installed, it's written down](#3-if-its-installed-its-written-down)
4. [What can't be automated gets a checklist](#4-what-cant-be-automated-gets-a-checklist)
5. [The same keys on every machine](#5-the-same-keys-on-every-machine)
6. [Private things stay out, and the seam is explicit](#6-private-things-stay-out-and-the-seam-is-explicit)
7. [Secrets live on hardware](#7-secrets-live-on-hardware)
8. [The laptop watches itself](#8-the-laptop-watches-itself)
9. [The reason sits next to the setting](#9-the-reason-sits-next-to-the-setting)

### 1. A new machine is one command away

A rebuild I have to remember how to do is a rebuild I'll get wrong. So there is one entry point, `make bootstrap`, and it is the same on every host. It:

1. installs system packages with `dnf`, `apt` or `brew bundle`, whichever the host has
2. installs Nix if it's missing
3. clones or updates the [private companion repo](#6-private-things-stay-out-and-the-seam-is-explicit)
4. applies the Home Manager configuration

The Makefile works out which host it's on and picks the matching flake profile (they're keyed `<username>-<distro>`: `.#json0-fedora`, `.#jsond-ubuntu`, `.#json0-darwin`, …). macOS runs the same target with a shorter tail. Suricata, auditd, pop-shell and xremap are Linux-only, and Tailscale and the GUI apps arrive as casks.

What you need before that works:

- Fedora (Workstation or a minimal install), Ubuntu, or macOS
- `git` and `make`
- the platform's package manager. `dnf` and `apt` come with the distro. On macOS, install [Homebrew](https://brew.sh) and the Xcode command line tools (`xcode-select --install`) first
- a network connection

### 2. The distro gets the minimum, Nix gets the rest

Every machine is split into two layers, and only the first one changes between hosts.

**The system layer** is whatever the OS's own package manager does best: the compositor, fonts, drivers, GUI apps. On Fedora and Ubuntu that's Sway, Waybar, Mako, swaylock and swayidle, listed in `fedora/system-packages.txt` and `ubuntu/system-packages.txt`. On macOS it's casks, fonts and mac-only tools in `mac/Brewfile`.

**The user layer** is Nix flakes plus Home Manager: CLI tools, development tooling, the shell, Neovim, tmux, and the symlinks that put every config file in place. It is identical on all three platforms, which is the point. The Brewfile deliberately holds nothing Home Manager can provide.

The line between them isn't taste. I tried taking Ghostty from nixpkgs and it launched, printed "Failed to create EGL display" and exited: on a non-NixOS host the Nix build looks for GPU drivers in the Nix store, not where the distro keeps them. So anything that talks to the GPU or the hardware stays in the system layer, and everything else moves to Nix. (`modules/packages.nix` has the longer version of that story.)

### 3. If it's installed, it's written down

A package I installed by hand at 11pm is a package the next rebuild won't have. Two targets keep me honest:

- `make drift-system` lists anything installed that isn't in the package file. (Apple's own App Store apps are kept installed but untracked, and the target knows not to judge them.)
- `make audit` reports pending security updates, flatpak updates and how old the flake inputs are.

`make update` pulls this repo and the private one, then applies routine updates across every channel.

### 4. What can't be automated gets a checklist

`make bootstrap` installs every package and config, but a rebuilt machine has the tools and not the sessions. Interactive logins and device pairings can't be scripted, so they're listed. This is the "why am I logged out?" list, done once per machine:

- **Proton Drive.** `proton-drive auth login` opens a browser to sign in. The session is then cached in libsecret, so you won't be asked again, and the `pdrive` wrapper (and its `pd` alias) work. How the binary is pinned and updated lives in `modules/services.nix`.
- **Signal.** Launch Signal, then on your phone go to *Settings → Linked devices → Link new device* and scan the QR code. History doesn't backfill; both devices sync forward from the link point. Same dance on macOS.
- **YubiKey (macOS).** Run `~/bin/yubikey-ssh-bootstrap` with the key plugged in to export the resident key handle (PIN + touch). Commit signing then needs the key passphrase and a touch per commit. Loading the key into an sk-capable ssh-agent (`ssh-add ~/.ssh/id_ed25519_sk_rk`, using the Nix openssh, because Apple's agent can't hold FIDO2 keys) reduces that to touch-only and lets tools without a terminal sign.

### 5. The same keys on every machine

I don't want to think about which laptop I'm on. Sway is the reference, and the others are bent to match it:

- GNOME sessions get pop-shell with keybindings that mirror Sway (`modules/gnome.nix`).
- macOS gets AeroSpace, which keeps each Sway key and swaps the modifier to ctrl+alt (`aerospace/aerospace.toml` explains why not cmd or alt).
- tmux, Neovim and lazygit come from the Nix layer, so they are the same files everywhere.

`Mod + /` opens a searchable cheatsheet of every binding, read live from the config, in both Sway and GNOME. The handful worth knowing before first login are in the [reference](#sway-keybinds).

### 6. Private things stay out, and the seam is explicit

A few files are personal enough that I don't publish them. They live in a private sibling repo at `~/Documents/workarea/local-config/`, and `make local-sync` clones it or brings it up to date.

That target runs as part of `make bootstrap`, ahead of Home Manager, because `home.nix` references files inside `local-config/` and the clone has to land first.

If you've cloned this repo without access to the private one, `make hm` and `make bootstrap` will fail at the `local-sync` step. Comment out the lines in `home.nix` that reference `local-config/`, or run the individual targets that don't depend on it.

### 7. Secrets live on hardware

SSH authentication and commit signing both go through a FIDO2 resident key on a YubiKey (`modules/ssh.nix`). Nothing on disk is enough to push as me or sign as me: it takes the key and a touch.

That costs some convenience, and I've written the costs down under [Gotchas](#gotchas) so they stop surprising me. (A tool with no terminal can't sign a commit. That is the design working, even when it's annoying.)

### 8. The laptop watches itself

On Linux, auditd keeps tamper watches on the files an attacker would touch to persist (`~/.ssh`, shell rc files, systemd user units, auditd's own config), and Sigma rules turn those records into named alerts. Each rule has a test that fires it on purpose, so I know it still works. Suricata runs as a passive IDS on Fedora.

None of it ships telemetry anywhere. It's a laptop, and the whole thing runs locally. [`detection/README.md`](detection/README.md) has the details.

### 9. The reason sits next to the setting

Most lines in these configs are there because something broke without them, and six months later I won't remember what. So the comment above a setting says why it exists, what was tried first, and how to check it's working. `tmux/tmux.conf` is the most thorough example.

Things with no file to live in go in [Gotchas](#gotchas).

---

## Reference

### Common commands

| Command | What it does |
| --- | --- |
| `make bootstrap` | Full rebuild: system packages, Nix, the private repo, Home Manager |
| `make system` | Install system packages (`dnf`, `apt` or `brew bundle`, detected per host) |
| `make hm` | Apply the Home Manager configuration |
| `make local-sync` | Clone or update the private companion repo |
| `make update` | Pull both repos, then apply routine updates on every channel |
| `make drift-system` | Show installed packages that aren't tracked |
| `make audit` | Report pending security updates and stale flake inputs |
| `make help` | Everything else, including the per-host extras |

### Sway keybinds

`Mod` is the Super (Windows) key. The full list lives in `sway/config`; these are the ones worth knowing before you've logged in for the first time.

**Session**

| Keys | Action |
| --- | --- |
| `Mod + Shift + r` | Reload Sway config |
| `Mod + Shift + q` | Lock screen |
| `Mod + Shift + s` | Lock, then suspend |
| `Mod + Shift + e` | Exit Sway (back to greeter) |
| `Mod + Shift + End` | Power menu (lock / suspend / hibernate / logout / reboot / shutdown) |
| `Mod + /` | Cheatsheet of all keybinds |

**Apps and windows**

| Keys | Action |
| --- | --- |
| `Mod + Return` | Open terminal |
| `Mod + d` | Application launcher (wofi) |
| `Mod + q` | Close focused window |
| `Mod + f` | Fullscreen toggle |
| `Mod + {h,j,k,l}` | Focus left / down / up / right |
| `Mod + Shift + {h,j,k,l}` | Move window left / down / up / right |
| `Mod + r` | Enter resize mode, then `hjkl` to resize and `Esc` to exit |
| `Mod + {1..4}` | Switch to workspace 1–4 |

**Screenshots**

| Keys | Action |
| --- | --- |
| `Print` | Area select → clipboard |
| `Shift + Print` | Full screen → clipboard |
| `Mod + Print` | Area select → `~/Pictures/screenshots/` |

**Audio and media**

Dedicated keys (`XF86AudioRaiseVolume`, `XF86AudioPlay`, etc.) work where the keyboard has them. For keyboards that don't, `Mod + PageUp/PageDown/End` cover volume and mute.

### Where things live

| Component | Location |
| --- | --- |
| Sway | `sway/config` |
| Waybar | `waybar/config` + `waybar/style.css` |
| Mako | `mako/config` |
| Swaylock | `swaylock/config` |
| GNOME keybindings | `modules/gnome.nix` |
| GNOME Shell extension (top CPU or memory process in the panel) | `gnome/top-consumer@jsond` |
| AeroSpace (macOS) | `aerospace/aerospace.toml` |
| tmux | `tmux/tmux.conf` |
| Neovim | `nvim/` |
| System packages | `fedora/system-packages.txt`, `ubuntu/system-packages.txt`, `mac/Brewfile` |
| User packages and config | `home.nix`, `modules/` |

### Gotchas

Things that have cost me a head-scratch, written down so they cost less next time.

- **The Proton Drive CLI skips Docs and Sheets.** `pdrive pull` (and the underlying `proton-drive filesystem download`) quietly skips anything stored as a Proton Doc or Sheet. Those live in Proton's editor in a proprietary format, not as real files. So a pull of a folder that holds only Docs finishes cleanly and downloads *nothing*, which looks broken but isn't. To get a Doc locally, export it from the Proton Docs web UI first. Regular files (PDFs, images, `.md`, …) come down fine.
- **Commit signing needs a TTY (or an agent).** The signing key file is passphrase-protected, so anything without a terminal (IDE commit buttons, AI agents, cron) fails with "incorrect passphrase supplied to decrypt private key". Fix: `ssh-add ~/.ssh/id_ed25519_sk_rk` once per login, or commit from a real terminal.
- **A short YubiKey touch types gibberish.** That's the OTP slot firing, not a bug. The FIDO2 touch only reads when ssh or ssh-keygen is actually waiting on the key.
