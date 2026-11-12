# Darwin Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `main` supports this MacBook Pro M1 with the same two-layer strategy as the Linux hosts: Homebrew as the system layer, standalone Home Manager as the user layer, driven by the same Makefile.

**Architecture:** Flake-level platform injection — `mkHome` gains a `system` parameter and conditionally includes the Linux-only modules (`services.nix`, `gnome.nix`); mixed modules branch on `pkgs.stdenv.hostPlatform.isLinux`. A new `dotfilesDir` module arg replaces the hard-coded repo path (this Mac's checkout is `dotfiles.nosync`).

**Tech Stack:** Nix flakes, Home Manager (standalone), GNU make, Homebrew + `brew bundle`.

**Spec:** `docs/superpowers/specs/2026-11-12-darwin-support-design.md` (uncommitted by choice — work from it).

## Global Constraints

- Conventional commit messages (`feat:`, `fix:`, `docs:`, …). NO `Co-Authored-By` trailers.
- **Commits cannot be made from an agent shell.** Commit signing uses the passphrase-protected YubiKey key `~/.ssh/id_ed25519_sk_rk` and needs a TTY. At each commit step, stage the files and give Jason the exact `git commit` command to run in his own terminal. Same for `git push`, `ssh` to GitHub, and `make local-sync`.
- The Linux hosts must keep working: after every flake/module change, `nix eval` of `json0-fedora` and `jsond-ubuntu` activation packages must still succeed.
- This Mac's checkout is `~/Documents/workarea/dotfiles.nosync` (iCloud-avoidance suffix). Linux hosts use `~/Documents/workarea/dotfiles`.
- Never run destructive steps (brew uninstall, branch deletion on origin, symlink removal) without showing the list and getting approval first, as promised in the spec.

---

### Task 1: Install Nix

Nothing in the flake can be tested until Nix exists on this machine.

**Files:** none (host-only change).

- [ ] **Step 1: Verify nix is absent, then install**

Run: `make nix`
This calls the Determinate Systems installer (`curl … install.determinate.systems/nix | sh -s -- install --no-confirm`), which handles macOS natively and enables flakes by default. It will ask for sudo — if the agent shell can't elevate, Jason runs `make nix` in his terminal.

- [ ] **Step 2: Verify**

Run (fresh shell, since the installer edits /etc/zshrc): `/nix/var/nix/profiles/default/bin/nix --version && /nix/var/nix/profiles/default/bin/nix flake metadata --json | jq -r .resolvedUrl`
Expected: a nix version ≥ 2.24, and the flake metadata resolves (proves flakes are enabled and the repo parses).

No commit (no repo change).

---

### Task 2: Teach distro detection about Darwin

**Files:**
- Modify: `common/detect-distro.sh`

**Interfaces:**
- Produces: the string `darwin` on macOS hosts; the Makefile's `DISTRO` variable and `FLAKE` (`.#json0-darwin`) follow automatically.

- [ ] **Step 1: Verify current failure**

Run: `bash common/detect-distro.sh; make help | head -1`
Expected: `unknown`, and `Host distro detected: unknown`.

- [ ] **Step 2: Add the Darwin branch**

In `common/detect-distro.sh`, insert after the header comment block / `set -euo pipefail` line (before the `/etc/os-release` check):

```bash
# macOS has no /etc/os-release; uname is the whole story there.
if [ "$(uname -s)" = Darwin ]; then
  echo darwin
  exit 0
fi
```

Also update the header comment on line 2 to: `# Print the host distro family: fedora | ubuntu | darwin | unknown.`

- [ ] **Step 3: Verify**

Run: `bash common/detect-distro.sh && make help | head -1`
Expected: `darwin`, and `Host distro detected: darwin   (override with DISTRO=fedora|ubuntu)`.

- [ ] **Step 4: Commit (Jason, in terminal)**

```bash
git add common/detect-distro.sh
git commit -m "feat: detect darwin in distro detection"
```

---

### Task 3: Flake-level platform injection (expected RED on darwin)

**Files:**
- Modify: `flake.nix`
- Modify: `home.nix`

**Interfaces:**
- Produces: `homeConfigurations."json0-darwin"`; module args `distro` (now may be `"darwin"`) and `dotfilesDir` (absolute path string) consumed by Tasks 4–6. `services.nix`/`gnome.nix` are now included by the flake, Linux-only.

- [ ] **Step 1: Replace `flake.nix` with:**

```nix
{
  description = "My Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # Username/home dir, system and host distro are the only per-machine
      # bits, so inject them here and keep home.nix machine-agnostic. Add a
      # line under homeConfigurations per host.
      #
      # `distro` is passed as a module arg so modules can branch on it — the
      # host distro can't be detected during a pure flake evaluation. It only
      # matters where the surrounding desktop differs (see modules/gnome.nix).
      # "darwin" is a distro like any other; the Makefile detects it the same
      # way (common/detect-distro.sh).
      #
      # `dotfilesRepo` is the repo directory name under ~/Documents/workarea.
      # The Mac checkout is "dotfiles.nosync" to keep iCloud's sync away from
      # it; the Linux hosts use plain "dotfiles". modules/dotfiles.nix and the
      # cdd alias consume the resulting absolute path (dotfilesDir).
      #
      # services.nix and gnome.nix are included only on Linux: Home Manager
      # does not define systemd.user.* options on Darwin, so importing
      # services.nix there is an eval error no amount of mkIf can guard.
      mkHome = username: { system ? "x86_64-linux", distro ? "fedora", dotfilesRepo ? "dotfiles" }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          isDarwin = nixpkgs.lib.hasSuffix "darwin" system;
          homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              _module.args.distro = distro;
              _module.args.dotfilesDir = "${homeDirectory}/Documents/workarea/${dotfilesRepo}";
            }
            ./home.nix
          ] ++ nixpkgs.lib.optionals (!isDarwin) [
            ./modules/services.nix
            ./modules/gnome.nix
          ];
        };
    in
    {
      # Keyed by "<username>-<distro>", not username alone: the same username
      # can exist on hosts running different distros, and the distro decides
      # which desktop assumptions apply (see modules/gnome.nix). The Makefile
      # selects the right one automatically — FLAKE defaults to
      # .#$(id -un)-$(DISTRO), with DISTRO from common/detect-distro.sh.
      homeConfigurations = {
        "json0-fedora" = mkHome "json0" { };
        "jsond-fedora" = mkHome "jsond" { };
        "jsond-ubuntu" = mkHome "jsond" { distro = "ubuntu"; };
        "json0-darwin" = mkHome "json0" {
          system = "aarch64-darwin";
          distro = "darwin";
          dotfilesRepo = "dotfiles.nosync";
        };
      };
    };
}
```

- [ ] **Step 2: Update `home.nix`** — remove the two Linux-only imports (now injected by the flake). The imports list becomes:

```nix
  imports = [
    ./modules/packages.nix # home.packages
    ./modules/shell.nix # bash/zsh, fzf, session vars & PATH
    ./modules/tmux.nix # programs.tmux
    ./modules/dotfiles.nix # home.file symlinks

    # services.nix (systemd user units) and gnome.nix (dconf) are imported by
    # flake.nix on Linux hosts only — systemd.user.* options don't exist in
    # Home Manager on Darwin, so they cannot be imported unconditionally here.

    # YubiKey-backed SSH auth + git commit signing. After the first
    # switch, run ~/bin/yubikey-ssh-bootstrap with the YubiKey plugged
    # in to export the resident key handle (PIN + touch).
    ./modules/ssh.nix
  ];
```

- [ ] **Step 3: Verify Linux hosts still evaluate, Darwin fails on Linux-only packages (RED)**

Run:
```bash
nix eval .#homeConfigurations.json0-fedora.activationPackage.drvPath
nix eval .#homeConfigurations.jsond-ubuntu.activationPackage.drvPath
nix eval .#homeConfigurations.json0-darwin.activationPackage.drvPath
```
Expected: both Linux attrs print a `.drv` path. The darwin attr FAILS mentioning a Linux-only package (e.g. `wl-kbptr`/`xremap` not available on `aarch64-darwin`). That failure is the point — Task 4 turns it green. If darwin fails on anything *other* than package availability (e.g. an option error), stop and investigate before Task 4.

- [ ] **Step 4: Commit (Jason, in terminal)**

```bash
git add flake.nix home.nix
git commit -m "feat: add json0-darwin home configuration with platform injection"
```

---

### Task 4: Guard packages for Darwin (GREEN)

**Files:**
- Modify: `modules/packages.nix`

**Interfaces:**
- Consumes: nothing new (uses `pkgs.stdenv`).
- Produces: a package set that evaluates on both platforms; Darwin gains nixpkgs `openssh`.

- [ ] **Step 1: Restructure the package list.** Change the module header to `{ pkgs, lib, ... }:` and move the Linux-only packages into a guarded list. Keep every existing comment with the package it belongs to. The structure becomes:

```nix
{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # --- Core Utilities ---
    fzf
    ripgrep
    fd
    bat
    jq
    yq-go # mikefarah's yq; plain `yq` in nixpkgs is the python jq-wrapper
    htop
    btop
    tree
    gnumake
    ack
    lnav # audit-log viewer on Linux, general log viewer everywhere

    # --- Network monitoring ---
    bandwhich
    tcpdump
    nmap
    termshark
    trippy
    dog

    # --- Git & Version Control ---
    git
    lazygit

    # --- Terminal Workspace ---
    ranger

    # --- Editors & Note Taking ---
    neovim
    newsboat

    # --- Development & Infrastructure ---
    go
    (python3.withPackages (ps: with ps; [
      pytest
      pytest-cov
      pytest-mock
      mypy
      ipython
      requests
      httpx
    ]))
    ruff
    uv
    pre-commit
    shellcheck
    shfmt
    nixpkgs-fmt
    nodejs
    kubectl
    k9s
    kubernetes-helm
    argocd
    argo-workflows
    opentofu
    terraform
    awscli2
    google-cloud-sdk
    sops
    age
    rustup
    # aider-chat removed 2026-11-12: its posthog dep is marked broken in
    # nixpkgs (locked rev AND latest unstable), failing eval on every host.
    # Jason approved dropping it — `uv tool install aider-chat` if missed.
    gemini-cli
    ollama
    github-cli
    exercism
    oha
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    # Wayland/X/desktop plumbing, Linux kernel interfaces, and tools whose
    # nixpkgs build is Linux-only. (gcc: macOS uses Apple clang; Nix's gcc on
    # a darwin host causes more linker trouble than it solves.)
    gcc
    wl-kbptr
    wlrctl
    wl-clipboard
    xclip
    playerctl
    wev
    pop-launcher
    nethogs
    xremap
    git-cola  # PyQt6 has no aarch64-darwin cache entry; lazygit is the daily driver
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # Apple ships OpenSSH without FIDO2/sk support, so the YubiKey resident
    # key (ssh.nix) needs ssh/ssh-keygen from nixpkgs. PATH puts
    # ~/.nix-profile/bin ahead of /usr/bin, so these win in HM-managed shells.
    openssh
  ];
}
```

Preserve the existing explanatory comments for the moved packages (brightnessctl note, pop-launcher paragraph, xclip note, ghostty-not-from-nixpkgs paragraph) — relocate them with their packages rather than deleting them.

- [ ] **Step 1b: Pin the signing program on Darwin.** (Added after field evidence: Apple's `/usr/bin/ssh-keygen` has no FIDO2 middleware — commit signing fails with "No FIDO SecurityKeyProvider specified" whenever PATH resolves to it, which varies by context.) In `modules/ssh.nix`, change the header to `{ lib, pkgs, ... }:` and add inside `programs.git.settings`:

```nix
      # Signing calls ssh-keygen; Apple's has no FIDO2 middleware and the
      # PATH winner varies by context (GUI apps, agents, cron see different
      # PATHs). Pin the Nix one on darwin so signing works everywhere.
      gpg.ssh.program = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "${pkgs.openssh}/bin/ssh-keygen";
```

- [ ] **Step 2: Verify all four attrs evaluate**

Run:
```bash
for a in json0-fedora jsond-fedora jsond-ubuntu json0-darwin; do
  nix eval .#homeConfigurations.$a.activationPackage.drvPath >/dev/null && echo "$a OK"
done
```
Expected: four `OK` lines. (Darwin may still fail here on shell.nix's `distro == "ubuntu"` check — it won't, both branches are strings — or on dotfiles.nix: file sources all exist in-repo, so eval passes even before Tasks 5–6 tidy them. Any failure: fix before continuing.)

- [ ] **Step 3: Commit (Jason, in terminal)**

```bash
git add modules/packages.nix modules/ssh.nix
git commit -m "feat: guard linux-only packages and add darwin openssh"
```

---

### Task 5: Shell — zsh on Darwin, Linux-only aliases guarded

**Files:**
- Modify: `modules/shell.nix`

**Interfaces:**
- Consumes: `dotfilesDir` module arg (Task 3).
- Produces: `programs.zsh` on Darwin with the shared aliases; `SSH_AUTH_SOCK` untouched on Darwin (launchd agent keeps working).

- [ ] **Step 1: Change the module header and hoist aliases.** Header becomes `{ pkgs, lib, distro, dotfilesDir, ... }:` and a `let` block above the config:

```nix
{ pkgs, lib, distro, dotfilesDir, ... }:

let
  # One alias set, two shells: bash gets all of these on Linux; zsh gets the
  # common ones on the Mac. The Linux-only aliases wrap auditd/suricata
  # tooling (ausearch, /var/log/audit) or Linux-only flags (`tcpdump -i any`
  # is a Linux pseudo-interface).
  commonAliases = {
    v = "nvim";
    vim = "nvim";
    g = "git";
    lg = "lazygit";
    r = "ranger";
    cdd = "cd ${dotfilesDir}";
    cdw = "cd ~/Documents/workarea";
    sniff = "sudo \"$(which bandwhich)\"";
    shark = "sudo \"$(which termshark)\"";
    pd = "pdrive";
  };
  linuxAliases = {
    alerts = "sudo ~/bin/suricata-alerts.sh";
    # auditd tamper watches (auditd/): -k does substring match, so one
    # alias covers every *-tamper key, including future rules files
    tamper = "ausearch -ts today -k tamper --format text";
    tampernew = "ausearch -k tamper --format text --checkpoint ~/.local/state/tamper.ckpt";
    tamperlog = "lnav /var/log/audit/audit.log -c ':filter-in key=\"[a-z-]+-tamper\"'";
    capture = "sudo tcpdump -i any -w /tmp/capture-$(date +%s).pcap";
  };
in
```

- [ ] **Step 2: Point bash at the merged set.** In `programs.bash`, replace the whole inline `shellAliases = { … };` attrset with:

```nix
    shellAliases = commonAliases // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux linuxAliases;
```

- [ ] **Step 3: Add zsh for Darwin.** After the `programs.bash` block, add:

```nix
  # The Mac keeps zsh (macOS default); the Linux hosts stay on bash + ble.sh.
  # This mirrors the bash setup above: same aliases, fzf/zoxide/direnv hooks,
  # typed-prefix history search on the arrow keys. hm-session-vars is sourced
  # by the HM-generated ~/.zshenv automatically.
  programs.zsh = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    shellAliases = commonAliases;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };
    initContent = ''
      setopt AUTO_CD

      # Up/down arrows search history filtered by what's already typed
      # (matches the readline config the Linux hosts get).
      autoload -U history-search-end
      zle -N history-beginning-search-backward-end history-search-end
      zle -N history-beginning-search-forward-end history-search-end
      bindkey '^[[A' history-beginning-search-backward-end
      bindkey '^[[B' history-beginning-search-forward-end
    '';
  };
```

- [ ] **Step 4: Enable zsh integration on the fzf/zoxide/direnv blocks.** Add `enableZshIntegration = true;` alongside the existing `enableBashIntegration = true;` in all three `programs.*` blocks.

- [ ] **Step 5: Guard SSH_AUTH_SOCK.** Replace the `home.sessionVariables` attrset with:

```nix
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    GIT_EDITOR = "nvim";
  } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    # Socket of the distro's user ssh-agent.service. Fedora's openssh unit
    # listens on %t/ssh-agent.socket, Ubuntu's on %t/openssh_agent. The
    # YubiKey hosts bypass the agent (IdentityAgent none), so a wrong path
    # only shows up as `ssh-add` failing and Host * never using the agent.
    # Darwin is untouched: launchd provides SSH_AUTH_SOCK there.
    SSH_AUTH_SOCK =
      if distro == "ubuntu"
      then "$XDG_RUNTIME_DIR/openssh_agent"
      else "$XDG_RUNTIME_DIR/ssh-agent.socket";
  };
```

- [ ] **Step 6: Verify**

Run the four-attr eval loop from Task 4 Step 2. Expected: four `OK`.
Also: `nix eval .#homeConfigurations.json0-darwin.config.programs.zsh.enable` → `true`, and `nix eval .#homeConfigurations.json0-fedora.config.programs.zsh.enable` → `false`.

- [ ] **Step 7: Commit (Jason, in terminal)**

```bash
git add modules/shell.nix
git commit -m "feat: zsh config on darwin and linux-only alias guards"
```

---

### Task 6: Dotfile symlinks — dotfilesDir + platform split; tmux battery; ghostty integration

**Files:**
- Modify: `modules/dotfiles.nix`
- Modify: `modules/tmux.nix`
- Modify: `ghostty/config`

- [ ] **Step 1: Rewrite `modules/dotfiles.nix`.** Header becomes `{ config, lib, pkgs, dotfilesDir, ... }:`. Every `mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/…"` becomes `mkOutOfStoreSymlink "${dotfilesDir}/…"` (the local-config entries keep using `config.home.homeDirectory` — that repo has no `.nosync` variant). Split the attrset: shared entries stay in the main set, Linux-only entries move to `// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux { … }`.

Shared set (keep existing comments):

```nix
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nvim";
    ".config/ranger/rc.conf".source = ../ranger/rc.conf;
    ".config/lazygit/config.yml".source = ../lazygit/config.yml;
    ".config/ghostty/config".source = ../ghostty/config;
    ".newsboat/config".source = ../newsboat/config;
    ".newsboat/urls".source = ../newsboat/urls;

    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/settings.json";
    ".claude/hooks".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/hooks";
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/skills";
    ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/agents";

    "bin/connection-checker.py".source = ../bin/connection-checker/connection-checker.py;
    "bin/view.py".source = ../bin/wakatime-view/view.py;
    "bin/yubikey-ssh-bootstrap" = {
      source = ../bin/yubikey-ssh-bootstrap/yubikey-ssh-bootstrap;
      executable = true;
    };
    "bin/pdrive" = {
      source = ../bin/pdrive/pdrive;
      executable = true;
    };
```

Linux-only set (keep existing comments): the sway entries (`config`, `cheatsheet.sh`, `powermenu.sh`, `sleep.sh`), `gnome/cheatsheet.sh`, the `top-consumer@jsond` extension link, `.config/swaylock/config`, both wofi entries, `.config/mako/config`, all three waybar entries, `.config/xremap/config.yml`, the lnav auditd format, the Fractal flatpak override, `bin/diagnosis.sh`, `bin/battery-remain.sh`, `bin/camera-relay.sh`, `bin/mozvpn`, and all three suricata scripts.

- [ ] **Step 2: tmux battery on Darwin.** In `modules/tmux.nix`, header becomes `{ pkgs, lib, ... }:` and the `extraConfig` gains a Darwin suffix after the existing plugin block:

```nix
    extraConfig = builtins.readFile ../tmux/tmux.conf + ''

      # ── Plugins (installed by Nix) ────────────────────────────
      run-shell ${pkgs.tmuxPlugins.resurrect.rtp}
      run-shell ${pkgs.tmuxPlugins.continuum.rtp}
      run-shell ${pkgs.tmuxPlugins.vim-tmux-navigator.rtp}
      run-shell ${pkgs.tmuxPlugins.battery.rtp}

      # vim-tmux-navigator binds C-h/j/k/l for pane navigation, which
      # steals C-l (clear screen). Reclaim it — must come *after* the
      # plugin's run-shell. Navigate right with M-l or prefix+l.
      unbind -n C-l
    '' + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''

      # bin/battery-remain.sh reads Linux sysfs; on macOS tmux-battery's own
      # #{battery_remain} works (pmset-based), so restate status-right with
      # the native token. Must come after the plugin run-shells above.
      set -g status-right "#[fg=#928374] Batt #{battery_percentage} #{battery_remain} #[fg=#665c54]│ #[fg=#928374]#(~/.completions/tmux_kube.sh) #[fg=#665c54]│ #[fg=#928374]Wakatime #(cd ~/bin; uv run view.py today) #[fg=#665c54]│ #[fg=#928374]Conn #(cd ~/bin; uv run connection-checker.py --tmux) #[fg=#665c54]│ #[fg=#a89984]%a %d %b %H:%M "
    '';
```

- [ ] **Step 3: Ghostty shell integration.** In `ghostty/config`, replace `shell-integration = bash` with:

```
# Auto-detect the login shell: bash on the Linux hosts, zsh on the Mac.
shell-integration = detect
```

Flag for later: verify on a Linux host at its next `make hm` that detection still picks bash (it launches $SHELL, so it will — but confirm).

- [ ] **Step 4: Verify**

Four-attr eval loop → four `OK`. Then confirm the split did what it should:
```bash
nix eval .#homeConfigurations.json0-darwin.config.home.file --apply 'f: builtins.attrNames f' | tr ',' '\n' | grep -c sway   # expect 0
nix eval .#homeConfigurations.json0-fedora.config.home.file --apply 'f: builtins.attrNames f' | tr ',' '\n' | grep -c sway  # expect >= 2
```

- [ ] **Step 5: Commit (Jason, in terminal)**

```bash
git add modules/dotfiles.nix modules/tmux.nix ghostty/config
git commit -m "feat: platform-aware dotfile symlinks, tmux battery and ghostty detect"
```

---

### Task 7: Makefile darwin branches

**Files:**
- Modify: `Makefile`
- Create: `mac/Brewfile` (starter — final contents come from Task 9's approved prune)

- [ ] **Step 1: Starter Brewfile.** Create `mac/Brewfile`:

```ruby
# System/GUI layer for the Mac — the darwin analogue of
# fedora/system-packages.txt. CLI tools come from Home Manager
# (modules/packages.nix); only casks, fonts and mac-only tools live here.
# `make drift-system` (brew bundle cleanup --dry-run) reports anything
# installed but not listed.

cask "ghostty"
cask "claude"
cask "tailscale-app"
cask "font-hack-nerd-font"
```

(Task 9 extends this with the approved keep list. These four are certain: the terminal, this tool, the tailnet, the font the terminal config expects.)

- [ ] **Step 2: PKGS_FILE for darwin.** In the Makefile, replace the `PKGS_FILE ?= $(DISTRO)/system-packages.txt` line (keep its comment) with:

```make
ifeq ($(DISTRO),darwin)
PKGS_FILE    ?= mac/Brewfile
else
PKGS_FILE    ?= $(DISTRO)/system-packages.txt
endif
```

- [ ] **Step 3: darwin-packages target.** After `ubuntu-packages`, add (the existing `system` target already dispatches to `$(DISTRO)-packages`, so no change needed there):

```make
.PHONY: darwin-packages
darwin-packages:
	test -f "mac/Brewfile"
	@echo "Installing Homebrew packages from mac/Brewfile…"
	brew bundle --file mac/Brewfile
```

- [ ] **Step 4: flatpak no-op.** Wrap the `flatpak` target body:

```make
.PHONY: flatpak
flatpak:
ifeq ($(DISTRO),darwin)
	@echo "flatpak is Linux-only; nothing to do on darwin."
else
	test -f "$(FLATPAK_FILE)"
	@echo "Ensuring Flathub remote is configured…"
	sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	@echo "Installing flatpaks from $(FLATPAK_FILE)…"
	@grep -vE '^\s*#|^\s*$$' "$(FLATPAK_FILE)" | while read -r remote app; do \
	  echo "  $$remote $$app"; \
	  sudo flatpak install -y --noninteractive "$$remote" "$$app"; \
	done
	@echo "Reloading session DBus so new app services are activatable now…"
	@gdbus call --session --dest org.freedesktop.DBus \
	  --object-path /org/freedesktop/DBus \
	  --method org.freedesktop.DBus.ReloadConfig >/dev/null 2>&1 || true
endif
```

- [ ] **Step 5: Per-distro bootstrap.** Replace the `bootstrap` rule with:

```make
# Darwin's tail is shorter by design: suricata/auditd/pop-shell/xremap are
# Linux-only, tailscale and firefox arrive as casks via mac/Brewfile, and
# flatpak no-ops (it stays listed so the recipe shape is identical).
.PHONY: bootstrap
ifeq ($(DISTRO),darwin)
bootstrap: system flatpak nix local-sync hm lint-install
else
bootstrap: system flatpak nix local-sync hm lint-install suricata auditd pop-shell xremap tailscale firefox-nightly
endif
	@echo "Bootstrap complete."
```

- [ ] **Step 6: Guard the Linux-only targets** following existing conventions — error when reaching the target on darwin means the request is wrong; no-op when it is a bootstrap/update prerequisite:

```make
# xremap: error (udev/uinput are Linux concepts)
.PHONY: xremap
xremap:
	@test "$(DISTRO)" != darwin || { \
	  echo "make xremap is Linux-only (udev rule + /dev/uinput)." >&2; exit 1; }
	@echo "Setting up xremap uinput access"
	bash common/setup-xremap.sh

# shinobi: error (usb-storage quirk is a Linux kernel parameter)
.PHONY: shinobi
shinobi:
	@test "$(DISTRO)" != darwin || { \
	  echo "make shinobi is Linux-only (usb-storage quirk via sysfs)." >&2; exit 1; }
	@echo "Setting up the TEX Shinobi keyboard usb-storage quirk"
	bash common/setup-tex-shinobi.sh

# tailscale: no-op (cask on the Mac; keeps `make tailscale` safe everywhere)
.PHONY: tailscale
tailscale:
ifeq ($(DISTRO),darwin)
	@echo "tailscale comes from mac/Brewfile on darwin; nothing to do."
else
	@echo "Setting up Tailscale"
	bash common/setup-tailscale.sh
endif

# auditd: error on darwin (auditd is the Linux audit framework)
.PHONY: auditd
auditd:
	@test "$(DISTRO)" != darwin || { \
	  echo "make auditd is Linux-only (the Linux audit framework)." >&2; exit 1; }
	@echo "Setting up auditd tamper watches"
	bash auditd/setup-auditd.sh

# suricata: extend the existing no-op to any non-Fedora distro
.PHONY: suricata
suricata:
ifeq ($(DISTRO),fedora)
	@echo "Setting up suricata"
	bash suricata/setup-suricata.sh
else
	@echo "suricata is Fedora-only in this setup; nothing to do on $(DISTRO)."
endif

# ghostty: extend the existing dispatch
.PHONY: ghostty
ghostty:
ifeq ($(DISTRO),ubuntu)
	@echo "ghostty comes from $(PKGS_FILE) on $(DISTRO); nothing to do."
else ifeq ($(DISTRO),darwin)
	@echo "ghostty comes from mac/Brewfile on darwin; nothing to do."
else
	@echo "Setting up Ghostty terminal (scottames/ghostty COPR)"
	bash fedora/setup-ghostty.sh
endif

# firefox-nightly: error on darwin (grab it as a cask if wanted)
.PHONY: firefox-nightly
firefox-nightly:
ifeq ($(DISTRO),darwin)
	@echo "firefox-nightly is handled via mac/Brewfile on darwin (cask 'firefox@nightly')." >&2
	@exit 1
else ifeq ($(DISTRO),ubuntu)
	@echo "Installing Firefox Nightly (Mozilla apt repository)"
	bash ubuntu/setup-firefox-nightly.sh
else
	@echo "Installing Firefox Nightly (Mozilla signed tarball)"
	bash fedora/setup-firefox-nightly.sh
endif

# pop-shell: extend the existing dispatch with a darwin arm
.PHONY: pop-shell
pop-shell:
ifeq ($(DISTRO),ubuntu)
	@echo "Building pop-shell from source (not packaged on Ubuntu)"
	bash ubuntu/setup-pop-shell.sh
else ifeq ($(DISTRO),darwin)
	@echo "pop-shell is a GNOME extension; nothing to do on darwin."
else
	@echo "pop-shell comes from fedora/system-packages.txt on $(DISTRO); nothing to do."
endif
```

(`nvidia`, `camera`, `displaylink`, `vpn` already error on anything that isn't their distro — their existing `test "$(DISTRO)" = fedora|ubuntu` guards cover darwin with no change. `sigma-scan`/`sigma-test` stay untouched: Linux-only in practice, but erroring from their own scripts is fine.)

- [ ] **Step 7: update/audit/drift darwin branches.**

`update` — wrap the system-upgrade and flatpak/auditd sections:

```make
.PHONY: update
update:
	@echo "=== System: upgrade ($(DISTRO)) ==="
ifeq ($(DISTRO),darwin)
	brew update
	brew upgrade
	brew bundle --file mac/Brewfile
else ifeq ($(DISTRO),ubuntu)
	sudo apt-get update
	sudo apt-get upgrade -y
else
	sudo dnf upgrade --refresh -y
endif
ifneq ($(DISTRO),darwin)
	@echo
	@echo "=== Flatpak: update ==="
	flatpak update -y
endif
	@echo
	@echo "=== Nix flake: update flake.lock ==="
	nix flake update
	@echo
	@echo "=== Home Manager: apply new generation ==="
	home-manager switch --flake "$(FLAKE)"
ifneq ($(DISTRO),darwin)
	@echo
	@echo "=== auditd: sync tamper watch rules ==="
	bash auditd/setup-auditd.sh
endif
	@echo
	@echo "=== uv: upgrade tools ==="
	uv tool upgrade --all
	@echo
	@echo "Update complete. If the kernel was updated, reboot to apply."
```

`audit` — add a darwin arm to the system section and skip flatpak:

```make
.PHONY: audit
audit:
	@echo "=== System: pending updates ($(DISTRO)) ==="
ifeq ($(DISTRO),darwin)
	@brew outdated || true
else ifeq ($(DISTRO),ubuntu)
	@if [ -x /usr/lib/update-notifier/apt-check ]; then \
	  /usr/lib/update-notifier/apt-check --human-readable || true; \
	else \
	  apt-get -s upgrade 2>/dev/null | grep -E '^Inst.*security' || echo "(none, or apt-check unavailable)"; \
	fi
else
	@dnf check-update --security || true
endif
ifneq ($(DISTRO),darwin)
	@echo
	@echo "=== Flatpak: pending updates ==="
	@flatpak remote-ls --updates || true
endif
	@echo
	@echo "=== Nix flake input age ==="
	@nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes | to_entries[] | select(.value.locked.lastModified) | "\(.key): \((now - .value.locked.lastModified) / 86400 | floor)d old"' || true
	@echo
	@echo "=== Proton Drive CLI: pinned vs latest ==="
	@bash bin/pdrive/pdrive-check-update.sh || true
```

`drift-system` — add a darwin arm:

```make
ifeq ($(DISTRO),darwin)
	@brew bundle cleanup --file mac/Brewfile || true
else ifeq ($(DISTRO),ubuntu)
	…existing comm pipeline…
else
	…existing comm pipeline…
endif
```

- [ ] **Step 8: help text.** In the `help` target, make exactly two line edits:

```make
	@echo "Host distro detected: $(DISTRO)   (override with DISTRO=fedora|ubuntu|darwin)"
	@echo "  make system             Install system packages for $(DISTRO) from $(PKGS_FILE)"
```
(the second line already interpolates `$(PKGS_FILE)`, which now reads `mac/Brewfile` on darwin — no change needed beyond confirming it renders correctly in `make help`).

- [ ] **Step 9: Verify every target's dispatch without executing side effects**

```bash
make help | head -3                      # detected: darwin
make -n system | head -3                 # shows brew bundle --file mac/Brewfile
make -n flatpak                          # shows the no-op echo
make -n bootstrap | head -5              # darwin dependency chain
make -n update | head -8                 # brew path, no apt/dnf
make xremap; echo "exit=$?"              # errors, exit=2 (make reports the failing recipe)
make suricata                            # "Fedora-only… nothing to do on darwin."
make tailscale                           # "comes from mac/Brewfile…"
```
Also re-run the Linux sanity check: `make -n system DISTRO=fedora | head -3` still shows the dnf path, and `make -n update DISTRO=ubuntu | head -6` still shows apt.

- [ ] **Step 10: Commit (Jason, in terminal)**

```bash
git add Makefile mac/Brewfile
git commit -m "feat: darwin branches for makefile targets and starter brewfile"
```

---

### Task 8: First switch — cleanup dotbot symlinks, apply Home Manager

This is the point of no return for the old setup; everything before it was pure repo work.

**Files:** none in repo (host mutation) — but requires Tasks 1–7 complete.

- [ ] **Step 1: Pre-build before touching anything**

Run: `nix build .#homeConfigurations.json0-darwin.activationPackage --no-link`
Expected: builds to completion (this downloads/builds every package — minutes, not seconds). Nothing on the host changes yet. Do NOT proceed past this step until it succeeds.

- [ ] **Step 2: local-config clone (Jason, in terminal — SSH needs YubiKey)**

```bash
make local-sync
```
Expected: clone (or pull) into `~/Documents/workarea/local-config` and its `setup.sh` runs. The `~/.claude` symlinks in Task 6 dangle without this.

- [ ] **Step 3: Inventory then remove the dotbot-era symlinks (approval gate)**

Show Jason the inventory first:
```bash
ls -la ~/.zshrc ~/.zshenv ~/.config/.zshenv ~/.tmux.conf ~/.ideavimrc ~/.gitconfig ~/.newsboat ~/.config/nvim ~/.config/ranger 2>/dev/null
```
Confirm each is a symlink into the repo (not a real file), get an explicit OK, then:
```bash
rm ~/.zshrc ~/.zshenv ~/.config/.zshenv ~/.tmux.conf ~/.ideavimrc ~/.gitconfig ~/.newsboat ~/.config/nvim ~/.config/ranger
```
(`rm` without `-r` — they are symlinks, including `.newsboat` and `.config/nvim`. If any turns out to be a real file/dir, stop and show it instead of deleting.)

Note: removing `~/.gitconfig` drops git identity until Step 4 restores it via `programs.git` — do Steps 3 and 4 back-to-back.

- [ ] **Step 4: Activate**

```bash
nix run github:nix-community/home-manager -- switch --flake .#json0-darwin
```
Expected: activation completes; "Creating home file links" without clobber errors. (After this first run, `home-manager` is on PATH via `programs.home-manager.enable`, so `make hm` works from then on.)

- [ ] **Step 5: Verify the user layer end-to-end**

```bash
zsh -ic 'alias cdd; which nvim fzf lazygit rg; echo $EDITOR'
# expect: cdd='cd /Users/json0/Documents/workarea/dotfiles.nosync',
#         all binaries under ~/.nix-profile/bin, EDITOR=nvim
git config --get user.name && git config --get gpg.format
# expect: Jason Birchall / ssh (now from ~/.config/git/config, not ~/.gitconfig)
ls -la ~/.config/nvim ~/.claude/settings.json ~/.config/ghostty/config
# expect: nvim → dotfiles.nosync/nvim (out-of-store), claude → local-config, ghostty → store
tmux kill-server 2>/dev/null; tmux new -d && tmux show -g status-right | grep -o battery_remain && tmux kill-server
# expect: the native #{battery_remain} token on darwin
```
Then a real-world check: open a new Ghostty window — zsh with autosuggestions, `v somefile` opens nvim, Ctrl-R gives fzf history.

- [ ] **Step 5b: Remove the interim signing override.** During implementation a repo-local `gpg.ssh.program` was set in `.git/config` (pointing at an ad-hoc nix store path, GC-rooted at `.superpowers/sdd/openssh-gcroot`) so Jason could sign commits before HM existed. HM now pins the same thing globally via `modules/ssh.nix`, and local config would shadow it forever:

```bash
git config unset --local gpg.ssh.program
rm .superpowers/sdd/openssh-gcroot
```

- [ ] **Step 6: Signing sanity (Jason, in terminal)**

```bash
git commit --allow-empty -m "test: signing check" && git log --show-signature -1 && git reset --hard HEAD~1
```
Expected: passphrase prompt + YubiKey touch, then "Good git signature". This proves the HM-managed git config signs exactly as before.

No commit (host-only task).

---

### Task 9: Brew prune — usage analysis, approved keep list, final Brewfile

**Files:**
- Modify: `mac/Brewfile`

- [x] **Step 1: Gather the evidence**

```bash
# Casks with last-opened dates (Spotlight)
for c in $(brew list --cask); do
  app=$(find /Applications ~/Applications -maxdepth 1 -iname "*${c%%-*}*" 2>/dev/null | head -1)
  printf '%-25s %s\n' "$c" "$(mdls -raw -name kMDItemLastUsedDate "${app:-/nonexistent}" 2>/dev/null)"
done
# Formulae: leaves with binary atimes, flagged when HM now provides them
comm -12 <(brew leaves | sort) <(ls ~/.nix-profile/bin | sort)   # provided by HM → remove
for f in $(brew leaves); do
  bin=$(ls /opt/homebrew/bin 2>/dev/null | grep -x "$f" || true)
  printf '%-30s %s\n' "$f" "${bin:+$(stat -f '%Sa' /opt/homebrew/bin/$bin)}"
done
```

- [x] **Step 2: Build the keep/remove table and get approval (gate)**

Three buckets, presented to Jason as a table with the evidence (last-used date / atime / HM-provides):
- **Remove — HM provides it:** every leaf in the `comm` intersection (expected: neovim, tmux, ripgrep, fzf, fd, bat, jq, lazygit, newsboat, ranger, gh, go, node, …).
- **Remove — stale:** casks unopened > 6 months (expected: warp 2023, goneovim, postman, …) and formulae with years-old atimes.
- **Keep:** recently used casks + anything Jason vetoes from the remove lists.
Do not uninstall anything until Jason approves the table.

- [x] **Step 3: Write the approved keeps into `mac/Brewfile`** (extending Task 7's starter — casks sorted alphabetically, `mas` entries only if Jason kept any, a `brew` section only for mac-only tools HM can't provide).

- [x] **Step 4: Prune** (type-restricted to `--formula --cask --tap` so untracked App Store apps survive; gpg-suite/karabiner-elements/session-manager-plugin need a sudo TTY — Jason runs that uninstall)

```bash
brew bundle cleanup --file mac/Brewfile          # dry-run: shows what would go
# → show output, confirm once more, then:
brew bundle cleanup --force --file mac/Brewfile
brew autoremove
brew bundle check --file mac/Brewfile && make drift-system
```
Expected: `brew bundle check` happy; `make drift-system` reports nothing to remove.

- [x] **Step 5: Verify nothing load-bearing vanished**

```bash
zsh -ic 'which nvim tmux rg fzf git lazygit'   # all still resolve (to ~/.nix-profile/bin)
```

- [ ] **Step 6: Commit (Jason, in terminal)**

```bash
git add mac/Brewfile
git commit -m "feat: usage-pruned brewfile as darwin system layer"
```

---

### Task 10: README

**Files:**
- Modify: `README.md`

- [x] **Step 1: Update the architecture framing.** The intro's "Personal Fedora workstation configuration" becomes platform-plural; the two-layer section gains darwin:

Under `## Architecture`, after the Fedora/system-layer section, add:

```markdown
### 1b. macOS (system layer)

Managed with Homebrew. GUI apps (casks), fonts and mac-only tools live in:

\```
mac/Brewfile
\```

CLI tooling comes from the Nix layer below, exactly as on Linux. `make
drift-system` reports anything installed outside the Brewfile.
```

And in the Nix section, replace the stale "active profile is `.#json0`" block with:

```markdown
The flake keys profiles by `<username>-<distro>`; the Makefile picks the
right one automatically (`.#json0-fedora`, `.#jsond-ubuntu`,
`.#json0-darwin`, …).
```

- [x] **Step 2: Bootstrap + dependencies.** In `# Dependencies`, note macOS needs Homebrew + Xcode CLT (`xcode-select --install`) instead of Fedora/dnf. In `## Bootstrap a New Machine`, note the same `make bootstrap` works on macOS and lists the shorter darwin chain.

- [x] **Step 3: Post-bootstrap manual steps** — add to the existing list:

```markdown
- **YubiKey (macOS)** — run `~/bin/yubikey-ssh-bootstrap` with the key
  plugged in to export the resident key handle (PIN + touch). Commit
  signing then needs the key passphrase + touch per commit; load the key
  into an sk-capable ssh-agent (`ssh-add ~/.ssh/id_ed25519_sk_rk`, using
  Homebrew/nix openssh — Apple's agent can't hold FIDO2 keys) to reduce
  that to touch-only and to let non-TTY tools (IDEs, agents) sign.
- **Signal (macOS)** — same device-link dance as Linux.
```

- [x] **Step 4: Gotchas** — add:

```markdown
- **Commit signing needs a TTY (or an agent).** The signing key file is
  passphrase-protected; anything without a terminal (IDE commit buttons,
  AI agents, cron) fails with "incorrect passphrase supplied to decrypt
  private key". Fix: `ssh-add ~/.ssh/id_ed25519_sk_rk` once per login, or
  commit from a real terminal.
- **A short YubiKey touch types gibberish.** That's the OTP slot firing,
  not a bug — the FIDO2 touch only reads when ssh/ssh-keygen is actually
  waiting on the key.
```

- [x] **Step 5: Verify** — `make lint` (pre-commit includes markdown hooks if configured; at minimum it must not fail on the README).

- [ ] **Step 6: Commit (Jason, in terminal)**

```bash
git add README.md
git commit -m "docs: document macos support and signing gotchas"
```

---

### Task 11: Repo cleanup — branches, default branch, legacy dirs

**Files:**
- Delete (if unreferenced): `zsh/` (only `zsh/packages` submodule stubs remain), `.gitmodules` entries pointing into it.

- [ ] **Step 1: Evidence per branch (no deletion yet)**

```bash
git fetch --all --prune
for b in 0a convert-lua fedora merge-lua; do
  echo "== $b: commits not on main =="; git log --oneline main..$b | head -5;
done
for b in origin/convert-lua origin/fedora origin/laptop origin/master origin/merge-lua origin/remove/jdk origin/ubuntu-support; do
  echo "== $b: commits not on main =="; git log --oneline main..$b | head -5;
done
```
Branches with zero unique commits are dead. Branches WITH unique commits: show Jason what they contain before touching them. (`mac-m1` has unique commits by definition — the archive tag covers it.)

- [ ] **Step 2: Present the deletion list and get approval (gate).** Nothing is deleted on origin without an explicit yes.

- [ ] **Step 3: Archive tag + default branch (Jason, in terminal — push needs YubiKey; tags are signed per `tag.gpgsign`)**

```bash
git tag -a archive/mac-m1 mac-m1 -m "dotbot-era mac setup, superseded by darwin support on main"
git push origin archive/mac-m1
gh repo edit --default-branch main
```

- [ ] **Step 4: Delete approved branches (Jason, in terminal)**

```bash
git push origin --delete convert-lua fedora laptop master merge-lua remove/jdk ubuntu-support mac-m1   # minus any Jason kept
git branch -D 0a convert-lua fedora merge-lua mac-m1
git fetch --prune
```

- [ ] **Step 5: Legacy `zsh/` dir.** Verify nothing references it, then remove:

```bash
grep -rn "zsh/" --include="*.nix" --include="Makefile" --include="*.sh" . | grep -v docs/ || echo "no references"
git rm -r zsh && git status
```
If `.gitmodules` lists `zsh/packages/*` submodules, `git rm` handles the index entries; also delete the stale sections from `.gitmodules` if git leaves them behind. If anything DOES reference `zsh/`, stop and show it.

- [ ] **Step 6: Commit (Jason, in terminal)**

```bash
git commit -m "chore: remove legacy zsh submodules and retire dead branches"
```

- [ ] **Step 7: Final verification**

```bash
git branch -a            # main (+ feature branch if used), origin/main only
gh repo view --json defaultBranchRef -q .defaultBranchRef.name   # main
make help | head -1      # darwin detected
make drift-system        # clean
nix eval .#homeConfigurations.json0-fedora.activationPackage.drvPath >/dev/null && echo "linux still OK"
```

---

## Deliberately out of scope (from the spec)

- nix-darwin, karabiner/iTerm salvage, the old Brewfile, bash-on-mac: all rejected during brainstorming.
- ssh-agent-based touch-only signing: documented in README (Task 10) as a manual opt-in, not automated — it changes signing UX on a security boundary, Jason's call when he wants it.
