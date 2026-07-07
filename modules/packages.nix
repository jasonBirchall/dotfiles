{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # --- Core Utilities ---
    fzf
    ripgrep
    fd
    bat
    jq
    htop
    btop
    tree
    gcc
    gnumake
    wl-kbptr
    wlrctl
    ack

    # --- Network monitoring ---
    bandwhich
    nethogs
    tcpdump
    nmap
    termshark
    trippy
    dog

    # --- Git & Version Control ---
    git
    lazygit
    commitizen
    git-cola

    # --- Terminal Workspace ---
    # tmux is installed via programs.tmux (see tmux.nix)
    ranger

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
    helm
    opentofu
    terraform
    awscli2
    sops
    age
    rustup
    aider-chat
    ollama
    github-cli
    exercism

    # --- Input remapping ---
    xremap
  ];
}
