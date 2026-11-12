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
ifeq ($(DISTRO),darwin)
PKGS_FILE    ?= mac/Brewfile
else
PKGS_FILE    ?= $(DISTRO)/system-packages.txt
endif
FLATPAK_FILE ?= common/flatpaks.txt

.PHONY: help
help:
	@echo "Host distro detected: $(DISTRO)   (override with DISTRO=fedora|ubuntu|darwin)"
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
	@echo "  make camera             Build the intel_cvs driver for Intel IPU7 cameras (Ubuntu only)"
	@echo "  make displaylink        Install the DisplayLink driver for the Dell D6000 dock (Ubuntu only)"
	@echo "  make xremap             Grant /dev/uinput access for xremap (udev rule + input group)"
	@echo "  make tailscale          Install Tailscale + enable tailscaled (then 'sudo tailscale up')"
	@echo "  make vpn                Set up the Mozilla Corporate VPN via NetworkManager (Ubuntu only)"
	@echo "                          Bundle from login.mozilla.com: make vpn BUNDLE=~/Downloads/you@mozilla.com.zip"
	@echo "  make firefox-nightly    Install Firefox Nightly (apt repo on Ubuntu, signed tarball on Fedora)"
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

.PHONY: darwin-packages
darwin-packages:
	test -f "mac/Brewfile"
	@echo "Installing Homebrew packages from mac/Brewfile…"
	brew bundle --file mac/Brewfile

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
# Darwin's tail is shorter by design: suricata/auditd/pop-shell/xremap are
# Linux-only, tailscale and firefox arrive as casks via mac/Brewfile, and
# flatpak no-ops (it stays listed so the recipe shape is identical).
.PHONY: bootstrap
ifeq ($(DISTRO),darwin)
bootstrap: system flatpak nix local-sync hm lint-install
else
bootstrap: system flatpak nix local-sync hm lint-install suricata auditd pop-shell xremap tailscale firefox-nightly
endif
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

# Ubuntu-only, and errors rather than no-ops on Fedora: the Fedora hosts have
# UVC webcams, so reaching this target there means something is wrong with the
# request, not with the host. Not in bootstrap — it builds an out-of-tree DKMS
# module and needs a reboot afterwards, so it stays a deliberate one-off. The
# script itself exits cleanly on a machine with no Intel CVS device.
.PHONY: camera
camera:
	@test "$(DISTRO)" = ubuntu || { \
	  echo "make camera is Ubuntu-only (out-of-tree intel_cvs via DKMS)." >&2; \
	  echo "Fedora hosts in this repo have UVC webcams and need nothing." >&2; exit 1; }
	@echo "Setting up the internal camera (Intel IPU7 / intel_cvs)"
	bash ubuntu/setup-camera.sh

# Ubuntu-only and errors elsewhere, for the same reason as `camera`: the D6000
# dock is on the work laptop, so reaching this on a Fedora host means the
# request is wrong. Not in bootstrap — it builds evdi via DKMS and adds the
# Synaptics apt repo, which only earns its keep on a host that meets the dock.
# After this, `make update` carries the driver forward through apt.
.PHONY: displaylink
displaylink:
	@test "$(DISTRO)" = ubuntu || { \
	  echo "make displaylink is Ubuntu-only (apt repo + Ubuntu's evdi-dkms)." >&2; \
	  echo "The Fedora hosts in this repo have no DisplayLink dock." >&2; exit 1; }
	@echo "Setting up the DisplayLink driver (Dell D6000 dock)"
	bash ubuntu/setup-displaylink.sh

# xremap: error (udev/uinput are Linux concepts)
.PHONY: xremap
xremap:
	@test "$(DISTRO)" != darwin || { \
	  echo "make xremap is Linux-only (udev rule + /dev/uinput)." >&2; exit 1; }
	@echo "Setting up xremap uinput access"
	bash common/setup-xremap.sh

# shinobi: error (usb-storage quirk is a Linux kernel parameter)
.PHONY: shinobi
shinobi:
	@test "$(DISTRO)" != darwin || { \
	  echo "make shinobi is Linux-only (usb-storage quirk via sysfs)." >&2; exit 1; }
	@echo "Setting up the TEX Shinobi keyboard usb-storage quirk"
	bash common/setup-tex-shinobi.sh

# pop-shell: extend the existing dispatch with a darwin arm
.PHONY: pop-shell
pop-shell:
ifeq ($(DISTRO),ubuntu)
	@echo "Building pop-shell from source (not packaged on Ubuntu)"
	bash ubuntu/setup-pop-shell.sh
else ifeq ($(DISTRO),darwin)
	@echo "pop-shell is a GNOME extension; nothing to do on darwin."
else
	@echo "pop-shell comes from fedora/system-packages.txt on $(DISTRO); nothing to do."
endif

# ghostty: extend the existing dispatch
.PHONY: ghostty
ghostty:
ifeq ($(DISTRO),ubuntu)
	@echo "ghostty comes from $(PKGS_FILE) on $(DISTRO); nothing to do."
else ifeq ($(DISTRO),darwin)
	@echo "ghostty comes from mac/Brewfile on darwin; nothing to do."
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

# Mozilla Corporate VPN (a.k.a. Global VPN) — not the consumer Mozilla VPN
# product, which is a different service entirely.
#
# Errors rather than no-ops off Ubuntu, the way `camera` does: the work VPN is
# on the laptop by choice, so reaching this on a Fedora box means the request
# is wrong rather than the host. If a Fedora host ever needs it, the script is
# distro-agnostic apart from its dpkg/apt calls.
#
# Deliberately not in `bootstrap`: it needs a bundle downloaded by hand from
# login.mozilla.com, and it hands over to an interactive upstream script, so it
# cannot succeed unattended on a fresh machine and would turn a clean bootstrap
# into a failed one. Re-runnable with no BUNDLE once the bundle is staged.
.PHONY: vpn
vpn:
	@test "$(DISTRO)" = ubuntu || { \
	  echo "make vpn is Ubuntu-only in this setup (the Fedora hosts are personal machines)." >&2; \
	  echo "Force it with DISTRO=ubuntu if that has changed." >&2; exit 1; }
	@echo "Importing the Mozilla Corporate VPN configuration"
	MOZVPN_DUOTYPE=$(DUOTYPE) MOZVPN_FORCE=$(FORCE) bash ubuntu/setup-vpn.sh $(BUNDLE)

# tailscale: no-op (cask on the Mac; keeps `make tailscale` safe everywhere)
.PHONY: tailscale
tailscale:
ifeq ($(DISTRO),darwin)
	@echo "tailscale comes from mac/Brewfile on darwin; nothing to do."
else
	@echo "Setting up Tailscale"
	bash common/setup-tailscale.sh
endif

# firefox-nightly: error on darwin (grab it as a cask if wanted)
.PHONY: firefox-nightly
firefox-nightly:
ifeq ($(DISTRO),darwin)
	@echo "firefox-nightly is handled via mac/Brewfile on darwin (cask 'firefox@nightly')." >&2
	@exit 1
else ifeq ($(DISTRO),ubuntu)
	@echo "Installing Firefox Nightly (Mozilla apt repository)"
	bash ubuntu/setup-firefox-nightly.sh
else
	@echo "Installing Firefox Nightly (Mozilla signed tarball)"
	bash fedora/setup-firefox-nightly.sh
endif

# Reports what's pending across the three update channels so you can decide
# whether to apply now or leave for the next routine update.
# - dnf check-update --security exits 100 if updates are available (not an error)
# - flatpak remote-ls --updates lists every pending flatpak update (no severity tagging)
# - nix flake metadata shows how stale each input is so flake.lock churn is visible
.PHONY: audit
audit:
	@echo "=== System: pending updates ($(DISTRO)) ==="
ifeq ($(DISTRO),darwin)
	@brew outdated || true
else ifeq ($(DISTRO),ubuntu)
	@if [ -x /usr/lib/update-notifier/apt-check ]; then \
	  /usr/lib/update-notifier/apt-check --human-readable || true; \
	else \
	  apt-get -s upgrade 2>/dev/null | grep -E '^Inst.*security' || echo "(none, or apt-check unavailable)"; \
	fi
else
	@dnf check-update --security || true
endif
ifneq ($(DISTRO),darwin)
	@echo
	@echo "=== Flatpak: pending updates ==="
	@flatpak remote-ls --updates || true
endif
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
ifeq ($(DISTRO),darwin)
	brew update
	brew upgrade
	brew bundle --file mac/Brewfile
else ifeq ($(DISTRO),ubuntu)
	sudo apt-get update
	sudo apt-get upgrade -y
else
	sudo dnf upgrade --refresh -y
endif
ifneq ($(DISTRO),darwin)
	@echo
	@echo "=== Flatpak: update ==="
	flatpak update -y
endif
	@echo
	@echo "=== Nix flake: update flake.lock ==="
	nix flake update
	@echo
	@echo "=== Home Manager: apply new generation ==="
	home-manager switch --flake "$(FLAKE)"
ifneq ($(DISTRO),darwin)
	@echo
	@echo "=== auditd: sync tamper watch rules ==="
	bash auditd/setup-auditd.sh
endif
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
ifeq ($(DISTRO),darwin)
	@brew bundle cleanup --file mac/Brewfile || true
else ifeq ($(DISTRO),ubuntu)
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
ifeq ($(DISTRO),darwin)
	@echo "flatpak is Linux-only; nothing to do on darwin."
else
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
endif

.PHONY: drift-flatpak
drift-flatpak:
	@echo "Flatpak drift (installed but not tracked in $(FLATPAK_FILE)):"
	@comm -23 \
	  <(flatpak list --app --columns=origin,application | tr '\t' ' ' | sort) \
	  <(grep -vE '^\s*#|^\s*$$' "$(FLATPAK_FILE)" | tr -s ' \t' ' ' | sort) || true

# auditd: error on darwin (auditd is the Linux audit framework)
.PHONY: auditd
auditd:
	@test "$(DISTRO)" != darwin || { \
	  echo "make auditd is Linux-only (the Linux audit framework)." >&2; exit 1; }
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

# suricata: extend the existing no-op to any non-Fedora distro
.PHONY: suricata
suricata:
ifeq ($(DISTRO),fedora)
	@echo "Setting up suricata"
	bash suricata/setup-suricata.sh
else
	@echo "suricata is Fedora-only in this setup; nothing to do on $(DISTRO)."
endif

.PHONY: suricata-update
suricata-update:
ifeq ($(DISTRO),ubuntu)
	@echo "suricata is Fedora-only in this setup; nothing to do on $(DISTRO)."
else
	@echo "Updating suricata rules"
	sudo systemctl restart suricata
endif
