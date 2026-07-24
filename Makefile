SHELL := /bin/bash

# Defaults to the current user's host config (.#<username>). flake.nix exposes
# one homeConfiguration per username via mkHome. Override with FLAKE=.#name.
FLAKE ?= .#$(shell id -un)
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
	@echo "  make ghostty            Install Ghostty terminal (enables scottames/ghostty COPR)"
	@echo "  make nvidia             Install proprietary NVIDIA driver + suspend setup"
	@echo "  make xremap             Grant /dev/uinput access for xremap (udev rule + input group)"
	@echo "  make tailscale          Install Tailscale + enable tailscaled (then 'sudo tailscale up')"
	@echo "  make local-sync         Clone or update the private local-config repo + run its setup hook"
	@echo "  make audit              Report pending security updates (dnf), flatpak updates, nix flake input age"
	@echo "  make update             Apply routine updates across all channels (dnf, flatpak, flake, hm, uv)"
	@echo ""
	@echo "Linting (pre-commit):"
	@echo "  make lint               Run all pre-commit hooks across every file"
	@echo "  make lint-staged        Run pre-commit hooks against staged changes only"
	@echo "  make lint-install       Install the git hooks into this clone (run once)"
	@echo "  make lint-update        Bump pinned hook revs in .pre-commit-config.yaml"
	@echo "  make drift-dnf          Show user-installed packages not in $(DNF_PKGS_FILE)"
	@echo "  make drift-flatpak      Show installed flatpaks not in $(FLATPAK_FILE)"

.PHONY: dnf
dnf:
	test -f "$(DNF_PKGS_FILE)"
	@echo "Installing DNF packages from $(DNF_PKGS_FILE)…"
	sudo dnf install -y $$(grep -vE '^\s*#|^\s*$$' "$(DNF_PKGS_FILE)" | tr '\n' ' ') --skip-unavailable

.PHONY: nix
nix:
	@if command -v nix >/dev/null 2>&1; then \
	  echo "Nix already installed."; \
	else \
	  echo "Installing Nix via the Determinate Systems installer (handles SELinux on Fedora)…"; \
	  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm; \
	fi

.PHONY: hm
hm:
	@echo "Applying Home Manager flake $(FLAKE)…"
	home-manager switch --flake "$(FLAKE)"

.PHONY: bootstrap
bootstrap: dnf flatpak nix local-sync hm lint-install suricata nvidia xremap tailscale
	@echo "Bootstrap complete."

# Clones or updates the private local-config repo (sibling of dotfiles) and
# runs its setup hook. Must run before `hm` because home.nix references files
# under local-config.
.PHONY: local-sync
local-sync:
	@echo "Syncing local-config (private)…"
	@if [ -d "$(HOME)/Documents/workarea/local-config/.git" ]; then \
	  git -C "$(HOME)/Documents/workarea/local-config" pull --ff-only; \
	else \
	  git clone git@github.com:jasonBirchall/local-config.git "$(HOME)/Documents/workarea/local-config"; \
	fi
	@if [ -x "$(HOME)/Documents/workarea/local-config/setup.sh" ]; then \
	  bash "$(HOME)/Documents/workarea/local-config/setup.sh"; \
	fi

.PHONY: xremap
xremap:
	@echo "Setting up xremap uinput access"
	bash fedora/setup-xremap.sh

.PHONY: ghostty
ghostty:
	@echo "Setting up Ghostty terminal"
	bash fedora/setup-ghostty.sh

.PHONY: nvidia
nvidia:
	@echo "Setting up NVIDIA proprietary driver + suspend"
	bash fedora/setup-nvidia.sh

.PHONY: tailscale
tailscale:
	@echo "Setting up Tailscale"
	bash fedora/setup-tailscale.sh

# Reports what's pending across the three update channels so you can decide
# whether to apply now or leave for the next routine update.
# - dnf check-update --security exits 100 if updates are available (not an error)
# - flatpak remote-ls --updates lists every pending flatpak update (no severity tagging)
# - nix flake metadata shows how stale each input is so flake.lock churn is visible
.PHONY: audit
audit:
	@echo "=== DNF: pending security updates ==="
	@dnf check-update --security || true
	@echo
	@echo "=== Flatpak: pending updates ==="
	@flatpak remote-ls --updates || true
	@echo
	@echo "=== Nix flake input age ==="
	@nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes | to_entries[] | select(.value.locked.lastModified) | "\(.key): \((now - .value.locked.lastModified) / 86400 | floor)d old"' || true
	@echo
	@echo "=== Proton Drive CLI: pinned vs latest ==="
	@bash bin/pdrive/pdrive-check-update.sh || true

# Routine cadence update across all four package channels.
# Order matters: flake update must come before `home-manager switch`, otherwise
# you'd apply an old flake.lock. uv tool upgrade is last because the companion
# tools depend on nothing else.
# Run weekly or biweekly. A kernel update may land here — reboot afterwards if so.
.PHONY: update
update:
	@echo "=== DNF: system upgrade ==="
	sudo dnf upgrade --refresh -y
	@echo
	@echo "=== Flatpak: update ==="
	flatpak update -y
	@echo
	@echo "=== Nix flake: update flake.lock ==="
	nix flake update
	@echo
	@echo "=== Home Manager: apply new generation ==="
	home-manager switch --flake "$(FLAKE)"
	@echo
	@echo "=== uv: upgrade tools ==="
	uv tool upgrade --all
	@echo
	@echo "Update complete. If the kernel was updated, reboot to apply."

# --- Linting (pre-commit) ---
# Tooling (pre-commit, shellcheck, shfmt, nixpkgs-fmt, ruff, commitizen) is
# installed via home.nix; hook definitions live in .pre-commit-config.yaml.
# `lint-install` wires the hooks into .git/hooks so they fire on commit; it is
# part of `bootstrap` but must be re-run in any fresh clone.
.PHONY: lint
lint:
	@echo "Running pre-commit across all files…"
	pre-commit run --all-files

.PHONY: lint-staged
lint-staged:
	@echo "Running pre-commit against staged changes…"
	pre-commit run

.PHONY: lint-install
lint-install:
	@echo "Installing pre-commit git hooks…"
	pre-commit install --install-hooks

.PHONY: lint-update
lint-update:
	@echo "Bumping pinned hook revisions…"
	pre-commit autoupdate

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
