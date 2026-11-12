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

{
  programs.bash = {
    enable = true;

    # ble.sh (fish/zsh-style autosuggestions + syntax highlighting) must be
    # sourced before anything that calls `bind` (fzf, zoxide) so it can
    # capture those bindings. It attaches at the very end of initExtra.
    bashrcExtra = ''
      [[ $- == *i* ]] && source ${pkgs.blesh}/share/blesh/ble.sh --attach=none
    '';

    shellAliases = commonAliases // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux linuxAliases;

    initExtra = lib.mkMerge [
      ''
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
        # Recursive globs: **/*.go matches at any depth (like zsh)
        shopt -s globstar
        # Typo-correct directory names during tab completion, not just in cd
        shopt -s dirspell
        # Tab on an empty line shouldn't dump every command in PATH
        shopt -s no_empty_cmd_completion

        # Source your specific completion scripts
        if [ -f ~/.completions/tmux_kube.sh ]; then
          source ~/.completions/tmux_kube.sh
        fi

        # Under ble.sh, fzf's stock widgets can't paste the selection back into
        # the command line (they write READLINE_LINE, which ble.sh's editor
        # ignores) — Ctrl-R would find a command but Enter wouldn't insert it.
        # ble.sh's contrib modules rebind Ctrl-R/Ctrl-T/Alt-C natively.
        if [[ ''${BLE_VERSION-} ]]; then
          _ble_contrib_fzf_base=${pkgs.fzf}/share/fzf
          # Re-read HISTFILE before and append after every command — ble's
          # equivalent of the `history -a; history -n` pair in __prompt_command
          # below, which must not run under ble.sh (see the comment there).
          bleopt history_share=1
          ble-import -d integration/fzf-completion
          ble-import -d integration/fzf-key-bindings

          # ble.sh's default RET inserts a newline whenever the buffer spans
          # several lines (a pasted heredoc, say) and expects C-j to run it,
          # but vim-tmux-navigator owns C-j. `accept-line syntax` runs the
          # command when it parses as complete and only inserts a newline
          # when it doesn't (open quote, unterminated `do`/`{`/heredoc).
          # This also silences the "-- MULTILINE -- (RET: newline, C-j: run)"
          # hint, which ble.sh shows only under its default bindings.
          ble-bind -f 'RET' 'accept-line syntax'
          ble-bind -f 'C-m' 'accept-line syntax'
          # Deliberate newline inside an otherwise complete command.
          ble-bind -f 'M-RET' 'newline'
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
          #
          # Plain bash only. Under ble.sh `history` is ble's wrapper, and its
          # `-n` re-reads the whole HISTFILE on the first prompt, which bash
          # then glues onto the last entry as one multi-line command. fzf's
          # Ctrl-R sees a single entry the size of the file that fuzzy-matches
          # every query, so it fills the screen with noise. ble.sh shares
          # history itself via `bleopt history_share` (set above).
          if [[ ! ''${BLE_VERSION-} ]]; then
            history -a
            history -n
          fi

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
      ''
      # mkAfter (1500) is where fzf/zoxide/direnv hooks land; attach ble.sh
      # after all of them so it wraps everything set up above.
      (lib.mkOrder 2000 ''
        [[ ! ''${BLE_VERSION-} ]] || ble-attach
      '')
    ];
  };

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

  # The Mac's prompt was starship under the dotbot-era zshrc; keep it, now
  # HM-managed. The Linux hosts keep the hand-rolled PS1 in bash above, so
  # bash integration stays off everywhere.
  programs.starship = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
  };

  # Readline: zsh-style completion & history navigation for every readline
  # program (bash, python REPL, psql, …).
  programs.readline = {
    enable = true;
    variables = {
      # cd doc<Tab> matches Documents
      completion-ignore-case = true;
      # One Tab lists all matches instead of demanding two
      show-all-if-ambiguous = true;
      # Colorize completion listings like zsh
      colored-stats = true;
      colored-completion-prefix = true;
      mark-symlinked-directories = true;
      skip-completed-text = true;
    };
    bindings = {
      # Up/down arrows search history filtered by what's already typed
      "\\e[A" = "history-search-backward";
      "\\e[B" = "history-search-forward";
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
      "--color=bw"
    ];
    defaultCommand = "fd --type f";
    fileWidget = {
      command = "fd --type f";
      options = [ "--preview 'bat --color=always --style=numbers --line-range=:200 {}'" ];
    };
  };

  # Smarter cd: `z dot` jumps to the most-used dir matching "dot",
  # `zi` fzf-picks from directory history.
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # Auto-load per-project environments from .envrc; nix-direnv caches
  # `use flake` dev shells so entering a project is instant.
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

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

  home.sessionPath = [
    "$HOME/.cargo/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
    "$HOME/bin"
  ];
}
