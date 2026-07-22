{ ... }:

{
  # home.username and home.homeDirectory are injected per-host by flake.nix
  # (see mkHome). This keeps home.nix machine-agnostic.
  #
  # This file is just the entry point: topic-focused modules live under
  # ./modules and are merged together by the module system via imports.

  imports = [
    ./modules/packages.nix # home.packages
    ./modules/shell.nix # bash, fzf, session vars & PATH
    ./modules/tmux.nix # programs.tmux
    ./modules/dotfiles.nix # home.file symlinks
    ./modules/services.nix # systemd user services/timers + activation
    ./modules/gnome.nix # GNOME + pop-shell dconf keybindings (mirrors sway)

    # YubiKey-backed SSH auth + git commit signing (shared with the
    # dotbot-managed machines via the mac-m1 branch). After the first
    # switch, run ~/bin/yubikey-ssh-bootstrap with the YubiKey plugged
    # in to export the resident key handle (PIN + touch).
    ./modules/ssh.nix
  ];

  home.stateVersion = "23.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
