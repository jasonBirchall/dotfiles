{ pkgs, lib, ... }:

{
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

  # gitingest isn't in nixpkgs, so install it as an isolated `uv tool`.
  # Idempotent: only runs when the executable is missing (e.g. first switch
  # on a new machine), so it won't hit the network on every activation and
  # can't break an offline `switch`. Run `uv tool upgrade gitingest` by hand
  # to bump it.
  home.activation.gitingestTool =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.local/bin/gitingest" ]; then
        run ${pkgs.uv}/bin/uv tool install gitingest
      fi
    '';
}
