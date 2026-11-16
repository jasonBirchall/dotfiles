{ config, lib, pkgs, dotfilesDir, ... }:

{
  home.file = {
    # Neovim (LazyVim) - Out-of-store symlink so it can write to lazy-lock.json
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nvim";
    ".config/ranger/rc.conf".source = ../ranger/rc.conf;
    ".config/lazygit/config.yml".source = ../lazygit/config.yml;
    ".config/ghostty/config".source = ../ghostty/config;
    ".newsboat/config".source = ../newsboat/config;
    ".newsboat/urls".source = ../newsboat/urls;

    # Sourced from the local-config private repo (sibling of dotfiles).
    # Run `make local-sync` to clone or update it before `make hm`.
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/settings.json";
    ".claude/hooks".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/hooks";
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/skills";
    ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/agents";

    # Custom scripts
    "bin/connection-checker.py".source = ../bin/connection-checker/connection-checker.py;
    "bin/view.py".source = ../bin/wakatime-view/view.py;
    "bin/yubikey-ssh-bootstrap" = {
      source = ../bin/yubikey-ssh-bootstrap/yubikey-ssh-bootstrap;
      executable = true;
    };

    # Proton Drive CLI wrapper (friendly verbs over the `proton-drive` binary)
    "bin/pdrive" = {
      source = ../bin/pdrive/pdrive;
      executable = true;
    };
  } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    ".config/sway/config".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/sway/config";
    ".config/sway/cheatsheet.sh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/sway/cheatsheet.sh";
    ".config/sway/powermenu.sh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/sway/powermenu.sh";
    ".config/sway/sleep.sh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/sway/sleep.sh";
    ".config/gnome/cheatsheet.sh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/gnome/cheatsheet.sh";

    # GNOME Shell only loads extensions from this directory, so the source
    # tree is linked into place rather than copied. Out-of-store because an
    # edit to extension.js should need a shell restart, not a `make hm`.
    # modules/gnome.nix names the same uuid in enabled-extensions.
    ".local/share/gnome-shell/extensions/top-consumer@jsond".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/gnome/top-consumer@jsond";

    ".config/swaylock/config".source = ../swaylock/config;
    ".config/wofi/config".source = ../wofi/config;
    ".config/wofi/style".source = ../wofi/style.css;
    ".config/mako/config".source = ../mako/config;
    ".config/waybar/config".source = ../waybar/config;
    ".config/waybar/style.css".source = ../waybar/style.css;
    ".config/waybar/launch.sh".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/waybar/launch.sh";

    "bin/diagnosis.sh".source = ../bin/debug/fedora_diagnosis.sh;

    # Stands in for tmux-battery's #{battery_remain}, which is broken on all
    # Linux hosts — see the header of the script for the two upstream bugs.
    # tmux/tmux.conf calls it from status-right.
    "bin/battery-remain.sh" = {
      source = ../bin/tmux-battery/battery-remain.sh;
      executable = true;
    };

    # Backs the camera-relay user service (modules/services.nix), which starts
    # it by path. Linked on both distros — it is inert without an Intel IPU7
    # camera, and the service that calls it only exists on Ubuntu.
    "bin/camera-relay.sh" = {
      source = ../bin/camera/camera-relay.sh;
      executable = true;
    };

    # Mozilla Corporate VPN wrapper over nmcli; profiles are imported by
    # `make vpn` (ubuntu/setup-vpn.sh). Linked on both distros for the same
    # reason as camera-relay.sh above — it is inert with no profiles imported,
    # and `mozvpn list` says so rather than failing. Out-of-store so `mozvpn
    # import` can find the repo by resolving its own symlink. No `executable`
    # attribute for the same reason as the other out-of-store entries: the mode
    # comes from the file in the repo, which pre-commit's
    # check-shebang-scripts-are-executable already enforces.
    "bin/mozvpn".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/bin/mozvpn/mozvpn";

    # Suricata scripts
    "bin/suricata-alerts.sh".source = ../bin/suricata/suricata-alerts.sh;
    "bin/suricata-watcher.sh".source = ../bin/suricata/suricata-watcher.sh;
    "bin/suricata-notify.sh".source = ../bin/suricata/suricata-notify.sh;

    ".config/xremap/config.yml".source = ../xremap/config.yml;

    # lnav format for the raw audit log; pairs with the auditd tamper watches
    # (auditd/) and log_group (wheel on Fedora, adm on Ubuntu), which makes
    # the log user-readable
    ".config/lnav/formats/dotfiles/auditd_log.json".source = ../lnav/formats/auditd_log.json;

    # Force GTK4's GL renderer for Fractal — Vulkan-on-Nvidia produces a blank window.
    ".local/share/flatpak/overrides/org.gnome.Fractal".source =
      ../flatpak/overrides/org.gnome.Fractal;
  } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    # AeroSpace is the Mac's stand-in for sway (the app is a cask in
    # mac/Brewfile). Out-of-store for the same reason as sway/config: an edit
    # needs a reload (ctrl-alt-shift-r), not a `make hm`.
    ".config/aerospace/aerospace.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/aerospace/aerospace.toml";
  };
}
