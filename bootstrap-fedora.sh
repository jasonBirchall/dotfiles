#!/usr/bin/env bash
set -e

# Install DNF system packages
sudo dnf install -y $(cat fedora/system-packages.txt)

# Install Nix (if not installed)
if ! command -v nix &>/dev/null; then
  sh <(curl -L https://nixos.org/nix/install)
fi

# Activate Home Manager
nix run home-manager/master -- switch --flake .#json0
