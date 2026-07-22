{ ... }:

{
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
      shark = "sudo \"$(which termshark)\"";
      pd = "pdrive";
    };

    initExtra = ''
      # Pull in home-manager session vars (PATH, EDITOR, …) for non-login interactive
      # shells too — .profile is only sourced by login shells.
      if [ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
        . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
      fi

      # Better History: ignore duplicates and space-started commands
      export HISTCONTROL=ignoreboth:erasedups
      export HISTSIZE=100000
      export HISTFILESIZE=100000

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

        # Bash only writes history on clean shell exit, so killed tmux panes
        # lose theirs and concurrent panes can't see each other's commands.
        # Flush after every command and pull in what other shells have written.
        history -a
        history -n

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
    fileWidget.command = "fd --type f";
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
}
