{ config, pkgs, ... }:

{
  # home.username and home.homeDirectory are injected per-host by flake.nix
  # (see mkHome). This keeps home.nix machine-agnostic.

  # YubiKey-backed SSH auth + git commit signing (shared with the
  # dotbot-managed machines via the mac-m1 branch). After the first
  # switch, run ~/bin/yubikey-ssh-bootstrap with the YubiKey plugged
  # in to export the resident key handle (PIN + touch).
  imports = [ ./nix/yubikey-ssh.nix ];

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
    # tmux is installed via programs.tmux below
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

  systemd.user.services.ollama = {
    Unit = {
      Description = "Ollama Local LLM Runner";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      Restart = "always";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

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
      # Pull in home-manager session vars (PATH, EDITOR, …) for non-login interactive
      # shells too — .profile is only sourced by login shells.
      if [ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
        . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
      fi

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

        # Working directory (basename only) — gruvbox gray (palette colour 7, #a89984)
        PS1+="\[\e[37m\]\W\[\e[0m\]"

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

  programs.tmux = {
    enable = true;
    prefix = "C-a";
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 10;
    historyLimit = 50000;
    mouse = true;
    focusEvents = true;
    aggressiveResize = true;
    clock24 = true;
    terminal = "tmux-256color";

    # tmux-sensible is prepended automatically (sensibleOnTop).
    # The remaining plugins are installed by Nix — no TPM. They are
    # appended *after* the readFile content so that settings like
    # @resurrect-* and the battery status-right tokens are already
    # in place when each plugin loads (home-manager's own `plugins`
    # option would load them too early).
    extraConfig = builtins.readFile ./tmux/tmux.conf + ''

      # ── Plugins (installed by Nix) ────────────────────────────
      run-shell ${pkgs.tmuxPlugins.resurrect.rtp}
      run-shell ${pkgs.tmuxPlugins.continuum.rtp}
      run-shell ${pkgs.tmuxPlugins.vim-tmux-navigator.rtp}
      run-shell ${pkgs.tmuxPlugins.battery.rtp}

      # vim-tmux-navigator binds C-h/j/k/l for pane navigation, which
      # steals C-l (clear screen). Reclaim it — must come *after* the
      # plugin's run-shell. Navigate right with M-l or prefix+l.
      unbind -n C-l
    '';
  };

  home.file = {
    # Neovim (LazyVim) - Out-of-store symlink so it can write to lazy-lock.json
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/nvim";
    ".config/ranger/rc.conf".source = ./ranger/rc.conf;
    ".config/lazygit/config.yml".source = ./lazygit/config.yml;
    ".config/sway/config".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/config";
    ".config/sway/cheatsheet.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/cheatsheet.sh";
    ".config/sway/powermenu.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/powermenu.sh";
    ".config/sway/sleep.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/sleep.sh";

    # Sourced from the local-config private repo (sibling of dotfiles).
    # Run `make local-sync` to clone or update it before `make hm`.
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/settings.json";
    ".claude/hooks".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/hooks";
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/skills";
    ".config/swaylock/config".source = ./swaylock/config;
    ".config/wofi/config".source = ./wofi/config;
    ".config/wofi/style".source = ./wofi/style.css;
    ".config/ghostty/config".source = ./ghostty/config;
    ".config/mako/config".source = ./mako/config;
    ".config/waybar/config".source = ./waybar/config;
    ".config/waybar/style.css".source = ./waybar/style.css;
    ".config/waybar/launch.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/waybar/launch.sh";
    ".newsboat/config".source = ./newsboat/config;
    ".newsboat/urls".source = ./newsboat/urls;

    # Custom scripts
    "bin/connection-checker.py".source = ./bin/connection-checker/connection-checker.py;
    "bin/diagnosis.sh".source = ./bin/debug/fedora_diagnosis.sh;
    "bin/view.py".source = ./bin/wakatime-view/view.py;
    "bin/yubikey-ssh-bootstrap" = {
      source = ./bin/yubikey-ssh-bootstrap/yubikey-ssh-bootstrap;
      executable = true;
    };

    # Suricata scripts
    "bin/suricata-alerts.sh".source = ./bin/suricata/suricata-alerts.sh;
    "bin/suricata-watcher.sh".source = ./bin/suricata/suricata-watcher.sh;
    "bin/suricata-notify.sh".source = ./bin/suricata/suricata-notify.sh;

    ".config/xremap/config.yml".source = ./xremap/config.yml;

    # Force GTK4's GL renderer for Fractal — Vulkan-on-Nvidia produces a blank window.
    ".local/share/flatpak/overrides/org.gnome.Fractal".source =
      ./flatpak/overrides/org.gnome.Fractal;
  };

  home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      GIT_EDITOR = "nvim";
      SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent.socket";
  };

  home.sessionPath = [
      "$HOME/.cargo/bin"
      "$HOME/.local/bin"
      "$HOME/go/bin"
      "$HOME/bin"
  ];

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

  systemd.user.services.xremap = {
    Unit = {
      Description = "xremap key remapper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.xremap}/bin/xremap %h/.config/xremap/config.yml";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
