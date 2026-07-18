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

  # Proton Drive CLI — Proton's official single-binary client (no nixpkgs
  # package yet). Fedora is glibc, so the linux-x64 build runs natively.
  # Pinned to a version + SHA-512; a mismatched download aborts rather than
  # installing. Idempotent like gitingest above: only fetches when the binary
  # is missing, so offline switches are fine. To upgrade: bump VER + SHA512
  # (from https://proton.me/download/drive/cli/) and
  # `rm ~/.local/bin/proton-drive` before the next switch.
  # First-time auth is a one-shot `proton-drive auth login` (browser-based;
  # the session is cached in libsecret — no password stored on disk).
  home.activation.protonDriveCli =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      VER=0.5.0
      SHA512=d85edbc57412c92a9705b70a8d3a5c66ad933331554d6b922b912d6df29b4e5e9b0d7a940a594927dd4788e1f8db86d5e9a23f084f07dbd5327f7a9e51d61272
      BIN="$HOME/.local/bin/proton-drive"
      if [ ! -x "$BIN" ]; then
        run ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/bin"
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        if run ${pkgs.curl}/bin/curl -fsSL \
            "https://proton.me/download/drive/cli/$VER/linux-x64/proton-drive" -o "$tmp" \
          && echo "$SHA512  $tmp" | ${pkgs.coreutils}/bin/sha512sum -c - >/dev/null 2>&1; then
          run ${pkgs.coreutils}/bin/install -m755 "$tmp" "$BIN"
        else
          echo "proton-drive: download/checksum failed — skipping install" >&2
        fi
        ${pkgs.coreutils}/bin/rm -f "$tmp"
      fi
    '';
}
