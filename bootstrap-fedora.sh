#!/usr/bin/env bash
set -e

# Install DNF system packages
mapfile -t pkgs <fedora/system-packages.txt
sudo dnf install -y "${pkgs[@]}"

# Install Nix (if not installed)
if ! command -v nix &>/dev/null; then
  sh <(curl -L https://nixos.org/nix/install)
fi

# Activate Home Manager (per-user config; flake.nix exposes one per username)
nix run home-manager/master -- switch --flake ".#$(id -un)"
