{ pkgs, lib, ... }:

{
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
    extraConfig = builtins.readFile ../tmux/tmux.conf
      + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''

      # bin/battery-remain.sh reads Linux sysfs; on macOS tmux-battery's own
      # #{battery_remain} works (pmset-based), so restate status-right with
      # the native token. Must come *before* the plugin run-shells below:
      # battery.tmux rewrites the #{battery_*} tokens in status-right once, at
      # load time. Set status-right after that and the tokens are never
      # rewritten — tmux expands them as unknown variables, i.e. to nothing.
      set -g status-right "#[fg=#928374] Batt #{battery_percentage} #{battery_remain} #[fg=#665c54]│ #[fg=#928374]#(~/.completions/tmux_kube.sh) #[fg=#665c54]│ #[fg=#928374]Wakatime #(cd ~/bin; ~/.nix-profile/bin/uv run view.py today) #[fg=#665c54]│ #[fg=#928374]Conn #(cd ~/bin; ~/.nix-profile/bin/uv run connection-checker.py --tmux) #[fg=#665c54]│ #[fg=#a89984]%a %d %b %H:%M "
    '' + ''

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
}
