# YubiKey SSH + git signing for home-manager machines.
# Import from home.nix: imports = [ ./modules/ssh.nix ];
#
# The key handle is a FIDO2 *resident* credential — after switching,
# run bin/yubikey-ssh-bootstrap (or `ssh-keygen -K`) once to export
# id_ed25519_sk_rk from the YubiKey. Needs PIN + touch.
#
# Fedora: works out of the box (system openssh has libfido2, udev rules
# ship with systemd); ykman comes from fedora/system-packages.txt.
# NixOS: add to configuration.nix:
#   services.udev.packages = [ pkgs.libfido2 ];   # USB access to the key
{ lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # "The YubiKey is waiting for a touch" — see the header of the askpass
  # script for what happens then. The two wrappers below are how it gets
  # called, and they differ because ssh and ssh-keygen announce the wait
  # differently.
  #
  # touchEnv is for ssh, which calls an askpass only when it believes there is
  # a display; this supplies a DISPLAY where nothing has (macOS). It is set
  # for that one process, never session-wide, so nothing else starts thinking
  # X11 is available.
  touchAskpass = ../bin/yubikey-touch/yubikey-askpass;
  touchEnv = ''
    export SSH_ASKPASS=${touchAskpass}
    [ -n "''${DISPLAY-}''${WAYLAND_DISPLAY-}" ] || export DISPLAY=:0
  '';

  # git's signing program. Apple's ssh-keygen has no FIDO2 middleware and the
  # PATH winner varies by context (GUI apps, agents, cron see different
  # PATHs), so darwin pins the Nix one; the Linux hosts keep the distro's.
  #
  # `ssh-keygen -Y sign` does not use the askpass for the touch: it only
  # prints "Confirm user presence for key …" on stderr, and git captures
  # that stderr, so the message used to go nowhere. So this reads ssh-keygen's
  # stderr itself, passes every line on untouched, and when that line goes by
  # starts the askpass script in its "key is waiting" mode. It is stopped
  # again (which lowers the flag) when ssh-keygen closes stderr, i.e. exits.
  # The passphrase and PIN prompts are not on stderr and are not affected.
  signProgram = pkgs.writeShellScript "ssh-keygen-touch-notify" ''
    exec 3>&2
    ${if isDarwin then "${pkgs.openssh}/bin/ssh-keygen" else "ssh-keygen"} "$@" 2> >(
      notifier=
      while IFS= read -r line; do
        printf '%s\n' "$line" >&3
        case $line in
          "Confirm user presence"*)
            SSH_ASKPASS_PROMPT=none ${touchAskpass} "$line" </dev/null >/dev/null 2>&1 3>&- &
            notifier=$!
            ;;
        esac
      done
      [ -z "$notifier" ] || kill "$notifier" 2>/dev/null
    )
  '';

  # git's ssh, for fetch and push. In a terminal ssh would print the message
  # on stderr and nothing else would hear about it; with stderr passed through
  # a pipe instead, ssh calls the askpass (which also prints the message, so
  # nothing is lost). Everything else ssh writes still reaches the terminal.
  gitSsh = pkgs.writeShellScript "git-ssh-touch-notify" ''
    ${touchEnv}
    if [ -t 2 ]; then
      exec ssh "$@" 2> >(cat >&2)
    fi
    exec ssh "$@"
  '';
in
{
  # Host blocks use upstream OpenSSH directive names under `settings` (the
  # `matchBlocks` API is deprecated). Unlike matchBlocks, `settings` injects
  # no implicit `Host *` defaults, so the wildcard block below re-declares the
  # values home-manager used to add for us. `*` is pinned last with
  # dag.entryAfter because ssh_config is first-match-wins — the specific hosts
  # must be consulted before the catch-all.
  programs.ssh = {
    enable = true;
    # Opt out of home-manager's implicit `Host *` defaults (deprecated, warns).
    # The wildcard block below supplies those values explicitly instead.
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        IdentitiesOnly = true;
        IdentityFile = "~/.ssh/id_ed25519_sk_rk";
        IdentityAgent = "none";
      };
      "codeberg.org" = {
        IdentitiesOnly = true;
        IdentityFile = "~/.ssh/id_ed25519_sk_rk";
        IdentityAgent = "none";
      };
      # Hetzner box (private, tailnet-only). No HostName: Tailscale MagicDNS
      # resolves the bare `blog` name when the tailnet is up, keeping the tailnet
      # address out of the repo. YubiKey only, touch required.
      "blog" = {
        User = "blog";
        IdentitiesOnly = true;
        IdentityFile = "~/.ssh/id_ed25519_sk_rk";
        IdentityAgent = "none";
      };
      "*" = lib.hm.dag.entryAfter [ "github.com" "codeberg.org" "blog" ] {
        AddKeysToAgent = "yes";
        Compression = false;
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        ForwardAgent = false;
        HashKnownHosts = false;
        IdentityFile = "~/.ssh/id_ed25519";
        ServerAliveCountMax = 3;
        ServerAliveInterval = 0;
        UserKnownHostsFile = "~/.ssh/known_hosts";
      };
    };
  };

  programs.git = {
    enable = true;
    signing = {
      key = "~/.ssh/id_ed25519_sk_rk.pub";
      signByDefault = true;
    };
    settings = {
      user.name = "Jason Birchall";
      user.email = "jason.birchall@pm.me";
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      # Both go through the touch-notify wrappers defined at the top.
      gpg.ssh.program = "${signProgram}";
      core.sshCommand = "${gitSsh}";
      tag.gpgsign = true;
    };
  };

  # Public keys trusted for signature verification — shared with the
  # dotbot-managed machines via ssh/allowed_signers in this repo.
  home.file.".ssh/allowed_signers".source = ../ssh/allowed_signers;
}
