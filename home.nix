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
    btop
    tree
    gcc
    gnumake
    wl-kbptr
    wlrctl

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
    rustup
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
      alerts = "sudo ~/bin/suricata-alerts.sh";
      sniff = "sudo \"$(which bandwhich)\"";
      capture = "sudo tcpdump -i any -w /tmp/capture-$(date +%s).pcap";
      shark = "termshark";
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

      # --- Prompt ---
      __git_branch() {
        git symbolic-ref --short HEAD 2>/dev/null
      }

      __prompt_command() {
        local exit_code=$?
        PS1=""

        # Red ✗ only on non-zero exit
        if [ $exit_code -ne 0 ]; then
          PS1+="\[\e[31m\]✗ \[\e[0m\]"
        fi

        # Working directory (basename only) — gruvbox blue
        PS1+="\[\e[34m\]\W\[\e[0m\]"

        # Git branch (only when in a repo)
        local branch
        branch=$(__git_branch)
        if [ -n "''${branch}" ]; then
          PS1+=" \[\e[33m\]''${branch}\[\e[0m\]"
        fi

        PS1+=" \$ "
      }

      PROMPT_COMMAND=__prompt_command
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
    ".config/sway/config".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/config";
    ".config/swaylock/config".source = ./swaylock/config;
    ".config/wofi/config".source = ./wofi/config;
    ".config/wofi/style".source = ./wofi/style.css;
    ".config/ghostty/config".source = ./ghostty/config;
    ".config/mako/config".source = ./mako/config;
    ".config/waybar/config".source = ./waybar/config;
    ".config/waybar/style.css".source = ./waybar/style.css;
    ".newsboat/config".source = ./newsboat/config;
    ".newsboat/urls".source = ./newsboat/urls;

    # Custom scripts
    "bin/connection-checker.py".source = ./bin/connection-checker/connection-checker.py;
    "bin/diagnosis.sh".source = ./bin/debug/fedora_diagnosis.sh;

    # Suricata scripts
    "bin/suricata-alerts.sh".source = ./bin/suricata/suricata-alerts.sh;
    "bin/suricata-watcher.sh".source = ./bin/suricata/suricata-watcher.sh;
    "bin/suricata-notify.sh".source = ./bin/suricata/suricata-notify.sh;
  };

  home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      GIT_EDITOR = "nvim";
  };

  # Suricata real-time alert watcher
  systemd.user.services.suricata-watcher = {
    Unit = {
      Description = "Suricata real-time alert watcher";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "%h/bin/suricata-watcher.sh";
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Hourly alert summary
  systemd.user.services.suricata-notify = {
    Unit = {
      Description = "Suricata hourly alert check";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "%h/bin/suricata-notify.sh";
    };
  };

  systemd.user.timers.suricata-notify = {
    Unit = {
      Description = "Hourly Suricata alert check";
    };
    Timer = {
      OnCalendar = "hourly";
      RandomizedDelaySec = 120;
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
