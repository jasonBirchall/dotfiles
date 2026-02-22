{ config, pkgs, ... }:

{
  # Remember to replace these with your actual Fedora username!
  home.username = "json0";
  home.homeDirectory = "/home/json0";

  home.stateVersion = "23.11"; 

  # Layer 1: Core FOSS CLI Packages
  home.packages = with pkgs; [
    # --- Core Utilities ---
    fzf
    ripgrep
    fd
    bat
    jq
    htop
    tree
    gcc
    gnumake

    # --- Git & Version Control ---
    git
    lazygit

    # --- Terminal Workspace ---
    tmux
    ranger

    # --- Editors & Note Taking ---
    neovim
    newsboat

    # --- Development & Infrastructure ---
    go
    python3
    uv
    nodejs
    kubectl
    k9s
    helm
    opentofu
  ];

  # Layer 2: Configuration Files
  home.file = {
    # Tmux
    ".tmux.conf".source = ./tmux/tmux.conf;
    # Layer 2: Configuration Files & Directories

    # Neovim (LazyVim) - Out-of-store symlink so it can write to lazy-lock.json
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/nvim";

    # Zsh Shell
    ".config/zsh/.zshenv".source = ./zsh/zshenv;
    ".config/zsh/.zshrc".source = ./zsh/zshrc;
    
    # Ranger
    ".config/ranger/rc.conf".source = ./ranger/rc.conf;

    # Custom scripts
    "bin/connection-checker.py".source = ./bin/connection-checker/connection-checker.py;
  };

  # Set default environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    GIT_EDITOR = "nvim";
  };
  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
