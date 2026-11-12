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

    # Formerly per-distro system packages. These are self-contained binaries
    # with no udev rules, system services or session integration, so taking
    # them from nixpkgs removes them from both package lists and keeps the
    # two distros on identical versions.
    #
    # brightnessctl deliberately stays a system package: Fedora's RPM ships
    # 90-brightnessctl.rules, and a Nix package cannot install a udev rule
    # that a non-NixOS udev will read.
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
    git-cola

    # --- Terminal Workspace ---
    # tmux is installed via programs.tmux (see tmux.nix)
    ranger
    # ghostty is deliberately NOT taken from nixpkgs. On a non-NixOS host the
    # Nix build links Nix's own libEGL, which searches the store for drivers
    # rather than the distro's /usr/lib/<triplet>; it launches, fails with
    # "Failed to create EGL display" and exits. GPU-backed GUI apps therefore
    # stay in the distro layer (see the Makefile's ghostty target). The CLI
    # tools above have no such dependency and are safe to take from Nix.

    # --- Editors & Note Taking ---
    neovim
    newsboat

    # --- Development & Infrastructure ---
    go
    # python3 wrapped with common dev libraries so `import pytest` and the
    # pytest/ipython/etc. CLIs work globally without a venv. For per-project
    # dependency pinning, reach for `uv` instead.
    (python3.withPackages (ps: with ps; [
      # Testing
      pytest
      pytest-cov
      pytest-mock
      # Types
      mypy
      # REPL & HTTP
      ipython
      requests
      httpx
    ]))
    ruff # standalone Rust binary (linter + formatter), not a python module
    uv
    pre-commit # git hook framework; config in .pre-commit-config.yaml
    shellcheck # shell linter (pre-commit)
    shfmt # shell formatter (pre-commit)
    nixpkgs-fmt # nix formatter (pre-commit)
    nodejs
    kubectl
    k9s
    kubernetes-helm # `helm` in nixpkgs is a synthesizer, of course
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
    oha # HTTP load generator; used against the AMO scanners' Cloud Run services
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    # Wayland/X/desktop plumbing, Linux kernel interfaces, and tools whose
    # nixpkgs build is Linux-only. (gcc: macOS uses Apple clang; Nix's gcc on
    # a darwin host causes more linker trouble than it solves.)
    gcc
    wl-kbptr
    wlrctl
    wl-clipboard
    xclip # nvim clipboard via Xwayland: no focus-grab window, see nvim/lua/config/options.lua
    playerctl
    wev

    # pop-shell's launcher (Super+d) is only a frontend: the search and launch
    # work is done by this separate binary over stdio. Without it the dialog
    # opens, accepts input and does nothing, which reads as a keybinding fault
    # rather than a missing dependency. Packaged on Fedora, unpackaged on
    # Ubuntu, so nixpkgs covers both from one line.
    pop-launcher

    nethogs

    # --- Input remapping ---
    xremap
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # Apple ships OpenSSH without FIDO2/sk support, so the YubiKey resident
    # key (ssh.nix) needs ssh/ssh-keygen from nixpkgs. PATH puts
    # ~/.nix-profile/bin ahead of /usr/bin, so these win in HM-managed shells.
    openssh
  ];
}
