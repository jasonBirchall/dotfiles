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

    # --- Git & Version Control ---
    git
    lazygit

    # --- Terminal Workspace ---
    ghostty
    tmux
    ranger

    # --- Editors & Note Taking ---
    neovim
    newsboat

    # --- Development & Infrastructure ---
    go
    python3
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
    
    # Zsh Shell
    ".config/zsh/.zshenv".source = ./zsh/zshenv;
    ".config/zsh/.zshrc".source = ./zsh/zshrc;
    
    # Ranger
    ".config/ranger/rc.conf".source = ./ranger/rc.conf;
  };
  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
