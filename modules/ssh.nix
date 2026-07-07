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
{ lib, ... }:

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
      tag.gpgsign = true;
    };
  };

  # Public keys trusted for signature verification — shared with the
  # dotbot-managed machines via ssh/allowed_signers in this repo.
  home.file.".ssh/allowed_signers".source = ../ssh/allowed_signers;
}
