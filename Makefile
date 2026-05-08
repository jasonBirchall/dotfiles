FLAKE ?= .#json0
DNF_PKGS_FILE ?= fedora/system-packages.txt

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make dnf                Install Fedora system packages from $(DNF_PKGS_FILE)"
	@echo "  make nix                Install Nix (if missing)"
	@echo "  make hm                 Apply Home Manager flake ($(FLAKE))"
	@echo "  make bootstrap          dnf + nix + hm"
	@echo "  make drift-dnf          Show user-installed packages not in $(DNF_PKGS_FILE)"
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
bootstrap: dnf nix hm suricata
	@echo "Bootstrap complete."

.PHONY: drift-dnf
drift-dnf:
	@echo "DNF drift (installed but not tracked in $(DNF_PKGS_FILE)):"
	comm -23 \
	  <(dnf repoquery --userinstalled | sort) \
	  <(grep -vE '^\s*#|^\s*$$' "$(DNF_PKGS_FILE)" | sort) || true

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
