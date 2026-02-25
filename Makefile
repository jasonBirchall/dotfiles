FLAKE ?= .#json0
DNF_PKGS_FILE ?= fedora/system-packages.txt

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make dnf            Install Fedora system packages from $(DNF_PKGS_FILE)"
	@echo "  make nix            Install Nix (if missing)"
	@echo "  make hm             Apply Home Manager flake ($(FLAKE))"
	@echo "  make bootstrap       dnf + nix + hm"
	@echo "  make drift-dnf       Show user-installed packages not in $(DNF_PKGS_FILE)"

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
