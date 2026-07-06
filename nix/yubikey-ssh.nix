# YubiKey SSH + git signing for home-manager machines.
# Import from home.nix: imports = [ ./nix/yubikey-ssh.nix ];
#
# The key handle is a FIDO2 *resident* credential — after switching,
# run bin/yubikey-ssh-bootstrap (or `ssh-keygen -K`) once to export
# id_ed25519_sk_rk from the YubiKey. Needs PIN + touch.
#
# Fedora: works out of the box (system openssh has libfido2, udev rules
# ship with systemd); ykman comes from fedora/system-packages.txt.
# NixOS: add to configuration.nix:
#   services.udev.packages = [ pkgs.libfido2 ];   # USB access to the key
{ pkgs, ... }:

{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      "github.com" = {
        identitiesOnly = true;
        identityFile = "~/.ssh/id_ed25519_sk_rk";
        extraOptions.IdentityAgent = "none";
      };
      "codeberg.org" = {
        identitiesOnly = true;
        identityFile = "~/.ssh/id_ed25519_sk_rk";
        extraOptions.IdentityAgent = "none";
      };
      # Hetzner box (private, tailnet-only). No HostName: Tailscale MagicDNS
      # resolves the bare `blog` name when the tailnet is up, keeping the tailnet
      # address out of the repo. YubiKey only, touch required.
      "blog" = {
        user = "blog";
        identitiesOnly = true;
        identityFile = "~/.ssh/id_ed25519_sk_rk";
        extraOptions.IdentityAgent = "none";
      };
      "*" = {
        addKeysToAgent = "yes";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  programs.git = {
    enable = true;
    userName = "Jason Birchall";
    userEmail = "jason.birchall@pm.me";
    signing = {
      key = "~/.ssh/id_ed25519_sk_rk.pub";
      signByDefault = true;
    };
    extraConfig = {
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      tag.gpgsign = true;
    };
  };

  # Public keys trusted for signature verification — shared with the
  # dotbot-managed machines via ssh/allowed_signers in this repo.
  home.file.".ssh/allowed_signers".source = ../ssh/allowed_signers;
}
