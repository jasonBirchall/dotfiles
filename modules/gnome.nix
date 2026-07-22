{ config, lib, ... }:

# GNOME + pop-shell, for sessions where GNOME is chosen at the GDM login
# screen instead of sway. The pop-shell extension itself is installed
# system-wide via fedora/system-packages.txt; this module enables it and
# mirrors the sway keybindings (sway/config) as closely as pop-shell allows.
#
# Sway bindings with no pop-shell analogue are left to GNOME's defaults:
# manual splits ($mod+v/b), tabbed layout ($mod+w), notification control
# ($mod+n), screenshots (GNOME's built-in Print handling), and the
# powermenu/sleep scripts. Window move and resize both live in pop-shell's
# adjustment mode — Super+r here, mirroring sway's resize mode — where
# arrows/hjkl move the window, Shift+direction resizes, Enter/Escape exits.

let
  inherit (lib.hm.gvariant) mkUint32;
in
{
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [ "pop-shell@system76.com" ];
    };

    "org/gnome/shell/extensions/pop-shell" = {
      tile-by-default = true;
      # Focused-window hint in the sway border orange (#ff5f00)
      active-hint = true;
      hint-color-rgba = "rgb(255,95,0)";
      # Gaps are in units of 4px; approximates sway's inner 14 / outer 6
      gap-inner = mkUint32 3;
      gap-outer = mkUint32 2;

      # Focus (vim style) — matches sway $mod+h/j/k/l
      focus-left = [ "<Super>h" ];
      focus-down = [ "<Super>j" ];
      focus-up = [ "<Super>k" ];
      focus-right = [ "<Super>l" ];

      # Adjustment mode on Super+r (sway's resize mode); frees Super+Return
      tile-enter = [ "<Super>r" ];
      # Pop-shell launcher on Super+d (sway's wofi binding)
      activate-launcher = [ "<Super>d" ];
      # Matches sway $mod+Shift+space / $mod+s
      toggle-floating = [ "<Super><Shift>space" ];
      toggle-stacking-global = [ "<Super>s" ];
    };

    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
      toggle-fullscreen = [ "<Super>f" ];
      # GNOME's default Super+h (minimize) would shadow focus-left
      minimize = [ ];

      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      move-to-workspace-1 = [ "<Super><Shift>1" ];
      move-to-workspace-2 = [ "<Super><Shift>2" ];
      move-to-workspace-3 = [ "<Super><Shift>3" ];
      move-to-workspace-4 = [ "<Super><Shift>4" ];
    };

    # Four fixed workspaces, like sway
    "org/gnome/mutter" = {
      dynamic-workspaces = false;
    };
    "org/gnome/desktop/wm/preferences" = {
      num-workspaces = 4;
    };

    "org/gnome/shell/keybindings" = {
      # GNOME binds Super+1..9 to dash favourites; free them for workspaces
      switch-to-application-1 = [ ];
      switch-to-application-2 = [ ];
      switch-to-application-3 = [ ];
      switch-to-application-4 = [ ];
      # Default Super+s (quick settings) would shadow toggle-stacking-global
      toggle-quick-settings = [ ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      # Lock on Super+Shift+q (sway's swaylock binding)
      screensaver = [ "<Super><Shift>q" ];
      # Volume on Mod+PgUp/PgDn/End alongside the dedicated media keys
      volume-up = [ "<Super>Prior" "XF86AudioRaiseVolume" ];
      volume-down = [ "<Super>Next" "XF86AudioLowerVolume" ];
      volume-mute = [ "<Super>End" "XF86AudioMute" ];
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Terminal";
      command = "ghostty";
      binding = "<Super>Return";
    };
    # Keybinding cheatsheet on Super+/ (sway's $mod+slash binding)
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name = "Keybinding cheatsheet";
      command = "${config.home.homeDirectory}/.config/gnome/cheatsheet.sh";
      binding = "<Super>slash";
    };
  };
}
