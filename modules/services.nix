{ pkgs, lib, distro ? "fedora", ... }:

# Suricata is Fedora-only here: the Ubuntu laptop runs the auditd tamper
# watches alone. Its units are therefore added with lib.optionalAttrs rather
# than disabled with lib.mkIf — mkIf suppresses the *value* but the attribute
# name still comes from the enclosing set, so home-manager would go on
# generating a unit for it. optionalAttrs drops the name outright, which is
# what "this host has no such service" needs to mean. Left in on a host with
# no Suricata, suricata-watcher restarts every 30s against a /var/log/suricata
# that never appears.
let
  onFedora = distro == "fedora";
  onUbuntu = distro == "ubuntu";
in
{
  systemd.user.services = {
    ollama = {
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

    xremap = {
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
  } // lib.optionalAttrs onUbuntu {
    # Bridges the libcamera camera into a v4l2loopback node for apps that
    # speak V4L2 and nothing else (Zoom, Chrome, Electron). Ubuntu-only: the
    # Fedora hosts have UVC webcams and need no bridge.
    #
    # Deliberately no Install section, so this never gets enabled. The
    # software ISP costs ~80% of one core for as long as it runs, which is not
    # something to leave on a laptop — `systemctl --user start camera-relay`
    # before a call, stop it after. ubuntu/setup-camera.sh says so on exit.
    #
    # Not restarted on failure for the same reason: the common failure is the
    # loopback node being absent, and retrying that in a loop burns a core
    # rather than fixing it.
    camera-relay = {
      Unit = {
        Description = "Relay libcamera to a V4L2 loopback node";
        Documentation = "https://github.com/intel/vision-drivers";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "%h/bin/camera-relay.sh";
        # The ISP work is not latency-critical to anything else on the desktop,
        # and at ~80% of a core it is the largest single thing competing for
        # CPU while a call is running. Keep it off the critical path.
        Nice = 5;
      };
    };
  } // lib.optionalAttrs onFedora {
    # Real-time alert watcher
    suricata-watcher = {
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
    suricata-notify = {
      Unit = {
        Description = "Suricata hourly alert check";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "%h/bin/suricata-notify.sh";
      };
    };
  };

  systemd.user.timers = lib.optionalAttrs onFedora {
    suricata-notify = {
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

  # sigma-cli lints the Sigma detection rules in detection/rules/ (the
  # sigma-check pre-commit hook and `sigma check` by hand). Same shape as
  # gitingest above: install once when missing, `uv tool upgrade` bumps it.
  home.activation.sigmaCliTool =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -x "$HOME/.local/bin/sigma" ]; then
        run ${pkgs.uv}/bin/uv tool install sigma-cli
      fi
    '';

  # Proton Drive CLI — Proton's official single-binary client (no nixpkgs
  # package yet). Fedora is glibc, so the linux-x64 build runs natively.
  # Pinned to a version + SHA-512; a mismatched download aborts rather than
  # installing. Fetches only when the binary is missing OR its version differs
  # from the pin, so routine offline switches never hit the network.
  # To upgrade: `make audit` tells you when a newer release is out and prints
  # the exact VER + SHA512 to paste below; then `make hm` swaps it in.
  # First-time auth is a one-shot `proton-drive auth login` (browser-based;
  # the session is cached in libsecret — no password stored on disk).
  home.activation.protonDriveCli =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      VER=0.7.0
      SHA512=5a5affcbec04ea926a32d10e236c1342227f1b6d416cb797f88f943b2c4f1dcf53b5897a115f1c1aa9ce8ce92fd637e1c50bd223b04866577681f0584eccdbc6
      BIN="$HOME/.local/bin/proton-drive"
      have=""
      if [ -x "$BIN" ]; then
        have="$("$BIN" --version 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oE 'cli-drive@[0-9.]+' | ${pkgs.coreutils}/bin/cut -d@ -f2 || true)"
      fi
      if [ "$have" != "$VER" ]; then
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
