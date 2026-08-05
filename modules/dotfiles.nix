{ config, ... }:

{
  home.file = {
    # Neovim (LazyVim) - Out-of-store symlink so it can write to lazy-lock.json
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/nvim";
    ".config/ranger/rc.conf".source = ../ranger/rc.conf;
    ".config/lazygit/config.yml".source = ../lazygit/config.yml;
    ".config/sway/config".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/config";
    ".config/sway/cheatsheet.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/cheatsheet.sh";
    ".config/sway/powermenu.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/powermenu.sh";
    ".config/sway/sleep.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/sway/sleep.sh";
    ".config/gnome/cheatsheet.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/gnome/cheatsheet.sh";

    # GNOME Shell only loads extensions from this directory, so the source
    # tree is linked into place rather than copied. Out-of-store because an
    # edit to extension.js should need a shell restart, not a `make hm`.
    # modules/gnome.nix names the same uuid in enabled-extensions.
    ".local/share/gnome-shell/extensions/top-consumer@jsond".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/gnome/top-consumer@jsond";

    # Sourced from the local-config private repo (sibling of dotfiles).
    # Run `make local-sync` to clone or update it before `make hm`.
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/settings.json";
    ".claude/hooks".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/hooks";
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/skills";
    ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/local-config/agents";
    ".config/swaylock/config".source = ../swaylock/config;
    ".config/wofi/config".source = ../wofi/config;
    ".config/wofi/style".source = ../wofi/style.css;
    ".config/ghostty/config".source = ../ghostty/config;
    ".config/mako/config".source = ../mako/config;
    ".config/waybar/config".source = ../waybar/config;
    ".config/waybar/style.css".source = ../waybar/style.css;
    ".config/waybar/launch.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/workarea/dotfiles/waybar/launch.sh";
    ".newsboat/config".source = ../newsboat/config;
    ".newsboat/urls".source = ../newsboat/urls;

    # Custom scripts
    "bin/connection-checker.py".source = ../bin/connection-checker/connection-checker.py;
    "bin/diagnosis.sh".source = ../bin/debug/fedora_diagnosis.sh;
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
  };
}
