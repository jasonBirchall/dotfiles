FLAKE ?= .#json0
DNF_PKGS_FILE ?= fedora/system-packages.txt
FLATPAK_FILE ?= fedora/flatpaks.txt

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make dnf                Install Fedora system packages from $(DNF_PKGS_FILE)"
	@echo "  make flatpak            Install flatpaks from $(FLATPAK_FILE)"
	@echo "  make nix                Install Nix (if missing)"
	@echo "  make hm                 Apply Home Manager flake ($(FLAKE))"
	@echo "  make bootstrap          dnf + flatpak + nix + hm"
	@echo "  make nvidia             Install proprietary NVIDIA driver + suspend setup"
	@echo "  make xremap             Grant /dev/uinput access for xremap (udev rule + input group)"
	@echo "  make drift-dnf          Show user-installed packages not in $(DNF_PKGS_FILE)"
	@echo "  make drift-flatpak      Show installed flatpaks not in $(FLATPAK_FILE)"
	@echo ""
	@echo "Recon (system inspection):"
	@echo "  make recon              Run all recon tools"
	@echo "  make recon-processes    Processes & services snapshot"
	@echo "  make recon-listening    Listening sockets / open ports"
	@echo "  make recon-outbound     Outbound traffic / DNS / connections"
	@echo "  make recon-autostart    systemd timers, cron, desktop autostart"
	@echo "  make recon-new NAME=x   Scaffold a new recon tool at bin/recon/x/"

.PHONY: dnf
dnf:
	test -f "$(DNF_PKGS_FILE)"
	@echo "Installing DNF packages from $(DNF_PKGS_FILE)…"
	sudo dnf install -y $$(grep -vE '^\s*#|^\s*$$' "$(DNF_PKGS_FILE)" | tr '\n' ' ')

.PHONY: nix
nix:
	@if command -v nix >/dev/null 2>&1; then \
	  echo "Nix already installed."; \
	else \
	  echo "Installing Nix…"; \
	  sh <(curl -L https://nixos.org/nix/install) --daemon; \
	fi

.PHONY: hm
hm:
	@echo "Applying Home Manager flake $(FLAKE)…"
	home-manager switch --flake "$(FLAKE)"

.PHONY: bootstrap
bootstrap: dnf flatpak nix hm suricata nvidia xremap
	@echo "Bootstrap complete."

.PHONY: xremap
xremap:
	@echo "Setting up xremap uinput access"
	bash fedora/setup-xremap.sh

.PHONY: nvidia
nvidia:
	@echo "Setting up NVIDIA proprietary driver + suspend"
	bash fedora/setup-nvidia.sh

.PHONY: drift-dnf
drift-dnf:
	@echo "DNF drift (installed but not tracked in $(DNF_PKGS_FILE)):"
	comm -23 \
	  <(dnf repoquery --userinstalled | sort) \
	  <(grep -vE '^\s*#|^\s*$$' "$(DNF_PKGS_FILE)" | sort) || true

.PHONY: flatpak
flatpak:
	test -f "$(FLATPAK_FILE)"
	@echo "Ensuring Flathub remote is configured…"
	sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	@echo "Installing flatpaks from $(FLATPAK_FILE)…"
	@grep -vE '^\s*#|^\s*$$' "$(FLATPAK_FILE)" | while read -r remote app; do \
	  echo "  $$remote $$app"; \
	  sudo flatpak install -y --noninteractive "$$remote" "$$app"; \
	done
	@echo "Reloading session DBus so new app services are activatable now…"
	@gdbus call --session --dest org.freedesktop.DBus \
	  --object-path /org/freedesktop/DBus \
	  --method org.freedesktop.DBus.ReloadConfig >/dev/null 2>&1 || true

.PHONY: drift-flatpak
drift-flatpak:
	@echo "Flatpak drift (installed but not tracked in $(FLATPAK_FILE)):"
	@comm -23 \
	  <(flatpak list --app --columns=origin,application | tr '\t' ' ' | sort) \
	  <(grep -vE '^\s*#|^\s*$$' "$(FLATPAK_FILE)" | tr -s ' \t' ' ' | sort) || true

.PHONY: suricata
suricata:
	@echo "Setting up suricata"
	bash suricata/setup-suricata.sh

.PHONY: suricata-update
suricata-update:
	@echo "Updating suricata rules"
	sudo systemctl restart suricata

RECON_TOOLS := processes listening outbound autostart

.PHONY: recon recon-processes recon-listening recon-outbound recon-autostart recon-new

recon: recon-processes recon-listening recon-outbound recon-autostart

recon-processes:
	@echo "=== recon: processes ==="
	@bin/recon/processes/processes.sh

recon-listening:
	@echo "=== recon: listening ==="
	@bin/recon/listening/listening.sh

recon-outbound:
	@echo "=== recon: outbound ==="
	@bin/recon/outbound/outbound.sh

recon-autostart:
	@echo "=== recon: autostart ==="
	@uv run --directory bin/recon python autostart/autostart.py

recon-new:
	@test -n "$(NAME)" || (echo "usage: make recon-new NAME=<tool>"; exit 1)
	@test ! -d "bin/recon/$(NAME)" || (echo "bin/recon/$(NAME) already exists"; exit 1)
	mkdir -p "bin/recon/$(NAME)"
	@printf '#!/usr/bin/env bash\nset -euo pipefail\n\n# TODO: describe what this tool answers\n\necho "TODO: implement $(NAME) recon"\n' > "bin/recon/$(NAME)/$(NAME).sh"
	chmod +x "bin/recon/$(NAME)/$(NAME).sh"
	@echo "Created bin/recon/$(NAME)/$(NAME).sh"
	@echo "Add '$(NAME)' to RECON_TOOLS in the Makefile to wire it into 'make recon'."
