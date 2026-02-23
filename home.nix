{ config, pkgs, ... }:

{
  home.username = "json0";
  home.homeDirectory = "/home/json0";

  home.stateVersion = "23.11"; 

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

    # --- Wayland / Sway ---
    sway
    swaybg
    swayidle
    swaylock
    waybar
    mako
    wl-clipboard
    grim
    slurp
    wofi
    brightnessctl
    playerctl
    networkmanagerapplet
  ];

  programs.bash = {
    enable = true;
    
    shellAliases = {
      v = "nvim";
      vim = "nvim";
      g = "git";
      lg = "lazygit";
      r = "ranger";
      cdd = "cd ~/Documents/workarea/dotfiles";
      cdw = "cd ~/Documents/workarea";
    };

    initExtra = ''
      # Better History: ignore duplicates and space-started commands
      export HISTCONTROL=ignoreboth:erasedups
      export HISTSIZE=10000
      export HISTFILESIZE=20000
      
      # Autocomplete cd: typing a directory name moves you there
      shopt -s autocd 
      
      # Correct minor directory typos
      shopt -s cdspell

      # Source your specific completion scripts
      if [ -f ~/.completions/tmux_kube.sh ]; then
        source ~/.completions/tmux_kube.sh
      fi
    '';
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
      "--color=bw"
    ];
    defaultCommand = "fd --type f";
    fileWidgetCommand = "fd --type f";
  };

  home.file = {
    ".tmux.conf".source = ./tmux/tmux.conf;
    # Neovim (LazyVim) - Out-of-store symlink so it can write to lazy-lock.json
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/nvim";
    ".config/ranger/rc.conf".source = ./ranger/rc.conf;
    ".config/sway/config".source = ./sway/config;
    ".config/waybar/config".source = ./waybar/config;
    ".config/waybar/style.css".source = ./waybar/style.css;

    # Custom scripts
    "bin/connection-checker.py".source = ./bin/connection-checker/connection-checker.py;
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    GIT_EDITOR = "nvim";

    # NVIDIA Wayland fixes
    WLR_NO_HARDWARE_CURSORS = "1";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_RENDERER = "vulkan";
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
