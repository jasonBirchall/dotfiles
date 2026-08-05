SHELL := /bin/bash

# Defaults to .#<username>-<distro>. flake.nix keys homeConfigurations on both
# because the same username exists on hosts running different distros, and the
# distro decides which desktop assumptions apply. Override with FLAKE=.#name.
# The '#' must be escaped: unescaped, make treats it as a comment and FLAKE
# silently collapses to '.', so `make hm` selects no homeConfiguration at all.
FLAKE ?= .\#$(shell id -un)-$(DISTRO)

# Host distro family: fedora | ubuntu | unknown. The detection lives in a script
# because $(shell ...) cannot contain an unescaped ')' — see common/detect-distro.sh.
# Override on the command line with DISTRO=fedora|ubuntu.
DISTRO ?= $(shell bash common/detect-distro.sh 2>/dev/null || echo unknown)

# System packages are per-distro; the flatpak list is shared, since flatpak
# itself is distro-agnostic and the app IDs are identical everywhere.
PKGS_FILE    ?= $(DISTRO)/system-packages.txt
FLATPAK_FILE ?= common/flatpaks.txt

.PHONY: help
help:
	@echo "Host distro detected: $(DISTRO)   (override with DISTRO=fedora|ubuntu)"
	@echo ""
	@echo "Targets:"
	@echo "  make system             Install system packages for $(DISTRO) from $(PKGS_FILE)"
	@echo "  make flatpak            Install flatpaks from $(FLATPAK_FILE)"
	@echo "  make nix                Install Nix (if missing)"
	@echo "  make hm                 Apply Home Manager flake ($(FLAKE))"
	@echo "  make bootstrap          system + flatpak + nix + hm"
	@echo "  make pop-shell          Install pop-shell (repo package on Fedora, source build on Ubuntu)"
	@echo "  make ghostty            Install Ghostty (COPR on Fedora; from $(PKGS_FILE) on Ubuntu)"
	@echo "  make nvidia             Install proprietary NVIDIA driver + suspend setup (Fedora only)"
	@echo "  make xremap             Grant /dev/uinput access for xremap (udev rule + input group)"
	@echo "  make tailscale          Install Tailscale + enable tailscaled (then 'sudo tailscale up')"
	@echo "  make suricata           Set up Suricata passive IDS (Fedora only; no-op elsewhere)"
	@echo "  make auditd             Install auditd tamper watches (~/.ssh, shell rc, systemd user units)"
	@echo "  make sigma-scan         Run Sigma rules (detection/rules/) over local telemetry via Zircolite"
	@echo "  make sigma-test         Fire Atomic Red Team-mapped triggers and assert each rule detects (SUDO=1 for root tests)"
	@echo "  make local-sync         Clone or update the private local-config repo + run its setup hook"
	@echo "  make audit              Report pending security updates (system), flatpak updates, nix flake input age"
	@echo "  make update             Apply routine updates across all channels (system, flatpak, flake, hm, auditd, uv)"
	@echo ""
	@echo "Linting (pre-commit):"
	@echo "  make lint               Run all pre-commit hooks across every file"
	@echo "  make lint-staged        Run pre-commit hooks against staged changes only"
	@echo "  make lint-install       Install the git hooks into this clone (run once)"
	@echo "  make lint-update        Bump pinned hook revs in .pre-commit-config.yaml"
	@echo "  make drift-system       Show user-installed packages not in $(PKGS_FILE)"
	@echo "  make drift-flatpak      Show installed flatpaks not in $(FLATPAK_FILE)"

# Entry point for system packages: dispatches to the detected distro. The
# per-distro targets stay callable by name so a specific one can be forced.
.PHONY: system
system:
	@test "$(DISTRO)" != unknown || { \
	  echo "Unrecognised distro (no fedora/rhel/debian/ubuntu in /etc/os-release)." >&2; \
	  echo "Set it explicitly: make system DISTRO=fedora|ubuntu" >&2; exit 1; }
	@$(MAKE) --no-print-directory $(DISTRO)-packages

.PHONY: fedora-packages
fedora-packages:
	test -f "fedora/system-packages.txt"
	@echo "Installing DNF packages from fedora/system-packages.txt…"
	sudo dnf install -y $$(grep -vE '^\s*#|^\s*$$' "fedora/system-packages.txt" | tr '\n' ' ') --skip-unavailable

# apt has no --skip-unavailable, and one unknown name aborts the whole
# transaction, so partition the list first and report what was dropped.
# Silently installing a subset would be worse than saying so.
.PHONY: ubuntu-packages
ubuntu-packages:
	test -f "ubuntu/system-packages.txt"
	@echo "Refreshing apt index…"
	sudo apt-get update -qq
	@avail=""; missing=""; \
	for p in $$(grep -vE '^\s*#|^\s*$$' "ubuntu/system-packages.txt"); do \
	  if apt-cache policy "$$p" 2>/dev/null | grep -qE 'Candidate: [^(]'; then \
	    avail="$$avail $$p"; \
	  else \
	    missing="$$missing $$p"; \
	  fi; \
	done; \
	if [ -n "$$missing" ]; then echo "Skipping unavailable:$$missing"; fi; \
	echo "Installing APT packages from ubuntu/system-packages.txt…"; \
	sudo apt-get install -y $$avail

# Back-compat: `make dnf` still works on the Fedora machine.
.PHONY: dnf
dnf: fedora-packages

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
	@test "$(DISTRO)" != unknown || { \
	  echo "Unrecognised distro, so the flake attribute cannot be chosen." >&2; \
	  echo "Set it explicitly: make hm DISTRO=fedora|ubuntu" >&2; exit 1; }
	@echo "Applying Home Manager flake $(FLAKE)…"
	home-manager switch --flake "$(FLAKE)"

# nvidia is not in the dependency list: it is Fedora-only and this laptop line
# ships Intel graphics. Run `make nvidia` explicitly on a machine that needs it.
.PHONY: bootstrap
bootstrap: system flatpak nix local-sync hm lint-install suricata auditd pop-shell xremap tailscale
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

# udev rule + input group; pure udev/usermod, so identical on both distros.
.PHONY: xremap
xremap:
	@echo "Setting up xremap uinput access"
	bash common/setup-xremap.sh

# Fedora packages pop-shell in its repos, so `make system` already installed it
# there and this is a no-op. Debian/Ubuntu don't package it at all, hence the
# source build. Same extension UUID either way, so modules/gnome.nix is shared.
.PHONY: pop-shell
pop-shell:
ifeq ($(DISTRO),ubuntu)
	@echo "Building pop-shell from source (not packaged on Ubuntu)"
	bash ubuntu/setup-pop-shell.sh
else
	@echo "pop-shell comes from fedora/system-packages.txt on $(DISTRO); nothing to do."
endif

# Fedora-only: akmod-nvidia lives in RPM Fusion and the suspend workaround is
# an SELinux policy module. Ubuntu users want `ubuntu-drivers install` instead.
# Ghostty stays a distro package rather than a Nix one. The nixpkgs build
# cannot create an EGL display on a non-NixOS host: it links Nix's libEGL,
# which looks for drivers inside the store instead of the distro's
# /usr/lib/<triplet>, so it starts and immediately exits. That applies to any
# GPU-backed GUI app — CLI tools in modules/packages.nix are unaffected.
#
# Ubuntu packages it, so `make system` already did the work. Fedora needs a
# third-party COPR enabled first, which is why it keeps a setup script.
.PHONY: ghostty
ghostty:
ifeq ($(DISTRO),ubuntu)
	@echo "ghostty comes from $(PKGS_FILE) on $(DISTRO); nothing to do."
else
	@echo "Setting up Ghostty terminal (scottames/ghostty COPR)"
	bash fedora/setup-ghostty.sh
endif

.PHONY: nvidia
nvidia:
	@test "$(DISTRO)" = fedora || { \
	  echo "make nvidia is Fedora-only (RPM Fusion akmod + SELinux policy)." >&2; \
	  echo "On Ubuntu use: sudo ubuntu-drivers install" >&2; exit 1; }
	@echo "Setting up NVIDIA proprietary driver + suspend"
	bash fedora/setup-nvidia.sh

# Upstream's installer detects the host distro itself, so this is shared.
.PHONY: tailscale
tailscale:
	@echo "Setting up Tailscale"
	bash common/setup-tailscale.sh

# Reports what's pending across the three update channels so you can decide
# whether to apply now or leave for the next routine update.
# - dnf check-update --security exits 100 if updates are available (not an error)
# - flatpak remote-ls --updates lists every pending flatpak update (no severity tagging)
# - nix flake metadata shows how stale each input is so flake.lock churn is visible
.PHONY: audit
audit:
	@echo "=== System: pending security updates ($(DISTRO)) ==="
ifeq ($(DISTRO),ubuntu)
	@# unattended-upgrades ships this; it is the only apt-side view that
	@# distinguishes security updates from ordinary ones.
	@if [ -x /usr/lib/update-notifier/apt-check ]; then \
	  /usr/lib/update-notifier/apt-check --human-readable || true; \
	else \
	  apt-get -s upgrade 2>/dev/null | grep -E '^Inst.*security' || echo "(none, or apt-check unavailable)"; \
	fi
else
	@dnf check-update --security || true
endif
	@echo
	@echo "=== Flatpak: pending updates ==="
	@flatpak remote-ls --updates || true
	@echo
	@echo "=== Nix flake input age ==="
	@nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes | to_entries[] | select(.value.locked.lastModified) | "\(.key): \((now - .value.locked.lastModified) / 86400 | floor)d old"' || true
	@echo
	@echo "=== Proton Drive CLI: pinned vs latest ==="
	@bash bin/pdrive/pdrive-check-update.sh || true

# Routine cadence update across all four package channels, plus config sync.
# Order matters: flake update must come before `home-manager switch`, otherwise
# you'd apply an old flake.lock. uv tool upgrade is last because the companion
# tools depend on nothing else. The auditd step syncs any new tamper watch
# rules pulled into the repo; it's drift-aware, so it's a no-op (no reload,
# no audit event) when nothing changed.
# Run weekly or biweekly. A kernel update may land here — reboot afterwards if so.
.PHONY: update
update:
	@echo "=== System: upgrade ($(DISTRO)) ==="
ifeq ($(DISTRO),ubuntu)
	sudo apt-get update
	sudo apt-get upgrade -y
else
	sudo dnf upgrade --refresh -y
endif
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
	@echo "=== auditd: sync tamper watch rules ==="
	bash auditd/setup-auditd.sh
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

# Packages installed by hand but never written back to the tracked list. On
# apt, apt-mark showmanual is the closest equivalent to dnf's --userinstalled;
# both include the base system, so expect a longer list on a fresh machine.
.PHONY: drift-system
drift-system:
	@echo "System drift (installed but not tracked in $(PKGS_FILE)):"
# LC_ALL=C on every sort and on comm itself. comm compares bytes, but a
# locale-aware sort orders punctuation differently (it ignores the '-' and '.'
# in names like docker-compose-v2 and docker.io). The orders then disagree,
# comm warns "file N is not in sorted order" and silently drops entries — so
# the drift list reads as clean when it is not.
ifeq ($(DISTRO),ubuntu)
	@LC_ALL=C comm -23 \
	  <(apt-mark showmanual | LC_ALL=C sort) \
	  <(grep -vE '^\s*#|^\s*$$' "$(PKGS_FILE)" | LC_ALL=C sort) || true
else
	@LC_ALL=C comm -23 \
	  <(dnf repoquery --userinstalled | LC_ALL=C sort) \
	  <(grep -vE '^\s*#|^\s*$$' "$(PKGS_FILE)" | LC_ALL=C sort) || true
endif

# Back-compat alias.
.PHONY: drift-dnf
drift-dnf: drift-system

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

.PHONY: auditd
auditd:
	@echo "Setting up auditd tamper watches"
	bash auditd/setup-auditd.sh

.PHONY: sigma-scan
sigma-scan:
	@echo "Running Sigma detection rules over local telemetry"
	bash detection/sigma-scan.sh

# Fires a trigger per rule (Atomic Red Team-mapped) and asserts the rule
# detects it. SUDO=1 also runs the tests that touch /etc/audit and the live
# ruleset. Tests clean up after themselves.
.PHONY: sigma-test
sigma-test:
	@echo "Running detection tests (Atomic Red Team-mapped)"
	bash detection/run-tests.sh $(if $(filter 1,$(SUDO)),--sudo,)

# Fedora-only by choice rather than by packaging: Ubuntu packages Suricata
# perfectly well, but the laptop runs the auditd tamper watches alone. This
# no-ops instead of erroring (unlike nvidia) because it is a bootstrap
# prerequisite, and bootstrap has to complete on both distros. The matching
# user units are omitted by modules/services.nix on the same condition.
.PHONY: suricata
suricata:
ifeq ($(DISTRO),ubuntu)
	@echo "suricata is Fedora-only in this setup; nothing to do on $(DISTRO)."
else
	@echo "Setting up suricata"
	bash suricata/setup-suricata.sh
endif

.PHONY: suricata-update
suricata-update:
ifeq ($(DISTRO),ubuntu)
	@echo "suricata is Fedora-only in this setup; nothing to do on $(DISTRO)."
else
	@echo "Updating suricata rules"
	sudo systemctl restart suricata
endif
