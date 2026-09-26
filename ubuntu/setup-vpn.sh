#!/usr/bin/env bash
# Set up the Mozilla Corporate VPN (Global VPN) via NetworkManager.
#
# The Ubuntu half of `make vpn`. There is deliberately no Fedora counterpart:
# the work VPN lives on the laptop alone, the Fedora boxes being personal.
#
# This is a *wrapper*, not an importer. The bundle from login.mozilla.com ships
# Mozilla's own `generate_nm_config` (Python, behind a /bin/sh shebang) and that
# is the supported path. Same reasoning as common/setup-tailscale.sh: let
# upstream own the part that changes.
#
# Read from the bundle dated 2026-08-21, upstream already does all of this, so
# none of it belongs here:
#   - rewrites each vpn-config-<endpoint>.conf into an .ovpn NM can import,
#     named for the `remote` host, then renames the connection down to the
#     first two dotted fields — so you get `openvpn.mdc1`, not the filename
#   - ipv4.never-default / ipv6.never-default, i.e. the split tunnel
#   - +vpn.data username=… from username.txt
#   - connection.autoconnect-retries, read out of the config's
#     `connect-retry-max`. This is the one worth understanding: NM does not
#     implement connect-retry-max at all and would otherwise fall back to its
#     own default of 4. Each endpoint has four remotes, so four retries is up
#     to sixteen Duo prompts from one failed connect, which is how people lock
#     their accounts. Re-implementing the import by hand would have dropped
#     that guard silently.
#   - the Duo password handling: `push` stores the literal string 'push'
#     (password-flags=0, and it is not a secret), `totp` stores nothing and
#     prompts each time (password-flags=2)
#
# What this script actually adds:
#   - the OpenVPN version gate, which is enforced server-side and otherwise
#     shows up as an auth failure rather than a version error
#   - staging the bundle to a private directory with 0600 keys, which the CLI
#     half of Mozilla's doc tells you to do by hand
#   - connection.autoconnect no, which upstream does not set
#   - a backstop on autoconnect-retries for the case where upstream's regex
#     finds no connect-retry-max and defaults it to 0 — which in NM means
#     *retry forever*, the worst available value here
#   - a sweep for decommissioned MDC2 profiles
#
# Mozilla's own framing is worth keeping in mind: Linux is community-supported
# (#linux on Slack), and their doc describes itself as "a collection of things
# that worked for people at one point" rather than golden-master instructions.
# Expect to adapt.
#
# Idempotent: safe to re-run. Re-running re-runs generate_nm_config against the
# staged bundle, which also repairs a profile that has been edited by hand.
set -euo pipefail

# Where the unpacked bundle lives. NOT ~/Downloads: the NM profiles reference
# the bundle's key material by absolute path, so the tunnel breaks the day you
# tidy up. Outside the dotfiles repo on purpose — these are private keys.
BUNDLE_DIR="${MOZVPN_BUNDLE_DIR:-$HOME/.config/mozilla-vpn}"

# OpenVPN version policy, from the SD/VPN article. dpkg --compare-versions
# rather than sort -V: it implements Debian ordering exactly, and this script
# is Ubuntu-only anyway.
VER_MIN="2.5.1"      # current minimum
VER_BLOCKED="2.5.0"  # blocked since 2024-01-02 (auth-nocache bug)
VER_UPCOMING="2.6.9" # minimum from 2026-10-05
VER_UPCOMING_DATE="2026-10-05"

# Duo method, passed to generate_nm_config as --duotype. Left empty, upstream
# prompts for it. 'push' sends a prompt to your phone; 'totp' asks for a code
# every connect.
DUOTYPE="${MOZVPN_DUOTYPE:-}"

# Skip upstream's "Automatically edit your NM config? [y/N]" confirmation and
# its overwrite-existing prompt. Off by default — the flag is hidden in
# upstream's argparse precisely because it should be a deliberate choice — but
# needed to re-run this unattended once profiles already exist.
FORCE="${MOZVPN_FORCE:-}"

say() { echo "[*] $*"; }
warn() { echo "[!] $*" >&2; }
die() {
  warn "$*"
  exit 1
}

usage() {
  cat <<EOF
Usage: bash ubuntu/setup-vpn.sh [PATH]

  PATH   Your VPN bundle: the .zip from login.mozilla.com, or the mozilla_vpn
         directory it unpacks to. Omit it to re-run against whatever is already
         staged in $BUNDLE_DIR.

Get a bundle from https://login.mozilla.com (it is named after your LDAP
address, e.g. jdoe@mozilla.com.zip).
EOF
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

# --- Preconditions ---------------------------------------------------------

# The Makefile guards this too, but the script has to stand alone: dpkg and the
# Debian package names below are Ubuntu-specific.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
distro="$(bash "$here/common/detect-distro.sh" 2>/dev/null || echo unknown)"
[ "$distro" = ubuntu ] || die "This script is Ubuntu-only (detected: $distro)."

command -v nmcli >/dev/null 2>&1 || die "nmcli not found. Is NetworkManager installed?"

# Mozilla's doc leads with this: without the openvpn package there is no
# OpenVPN option in NetworkManager at all, which presents as "the VPN type is
# missing" rather than as anything about openvpn.
command -v openvpn >/dev/null 2>&1 ||
  die "openvpn not found. Run 'make system' — it is in ubuntu/system-packages.txt."

# Check for the plugin's .name file rather than the deb, because that is what
# NM actually reads. Missing, the import fails with "unknown VPN service type".
[ -f /usr/lib/NetworkManager/VPN/nm-openvpn-service.name ] ||
  die "The NetworkManager OpenVPN plugin is missing.
    sudo apt-get install network-manager-openvpn network-manager-openvpn-gnome"

# --- OpenVPN version gate --------------------------------------------------
#
# Up front rather than as a surprise later: the server enforces this, so a
# too-old client authenticates and is then dropped. That looks exactly like a
# credential problem, and Mozilla's own AUTH_FAILED triage list starts by
# asking whether you are on a supported version.
ov_ver="$(openvpn --version 2>/dev/null | head -1 | awk '{print $2}')"
[ -n "$ov_ver" ] || die "Could not parse the output of 'openvpn --version'."
say "OpenVPN $ov_ver"

if [ "$ov_ver" = "$VER_BLOCKED" ]; then
  die "OpenVPN $VER_BLOCKED is blocked by Mozilla (since 2024-01-02, auth-nocache bug).
    Upgrade before connecting: sudo apt-get install --only-upgrade openvpn"
fi
dpkg --compare-versions "$ov_ver" ge "$VER_MIN" ||
  die "OpenVPN $ov_ver is below Mozilla's minimum of $VER_MIN.
    Upgrade: sudo apt-get install --only-upgrade openvpn"

if ! dpkg --compare-versions "$ov_ver" ge "$VER_UPCOMING"; then
  warn "OpenVPN $ov_ver meets today's minimum but not the $VER_UPCOMING one taking"
  warn "    effect on $VER_UPCOMING_DATE. Ubuntu 24.04 ships $VER_UPCOMING, so 'make update'"
  warn "    or a release upgrade should cover it — but do not leave it to the day."
fi

# --- Stage the bundle ------------------------------------------------------

install -d -m 0700 "$BUNDLE_DIR"

src="${1:-}"
if [ -n "$src" ]; then
  [ -e "$src" ] || die "No such path: $src"
  case "$src" in
    *.zip)
      command -v unzip >/dev/null 2>&1 ||
        die "unzip is needed to unpack $src (sudo apt-get install unzip)."
      say "Unpacking $src into $BUNDLE_DIR…"
      # Structure is preserved, not flattened: the zip unpacks to a mozilla_vpn/
      # directory and generate_nm_config expects to run from inside it.
      unzip -o -q "$src" -d "$BUNDLE_DIR"
      ;;
    *)
      [ -d "$src" ] || die "$src is neither a .zip nor a directory."
      say "Staging $src into $BUNDLE_DIR…"
      cp -a "$src" "$BUNDLE_DIR/"
      ;;
  esac
fi

# The .conf files carry your client key. Mozilla's CLI instructions say to
# chmod them 0600 by hand; do it here so it cannot be forgotten, and do it
# unconditionally rather than trusting the modes that came out of the zip.
# OpenVPN only *warns* about world-readable keys and then carries on, so
# nothing downstream will catch this for us.
chmod -R u=rwX,go= "$BUNDLE_DIR"

# --- Hand over to Mozilla's importer ---------------------------------------

gen="$(find "$BUNDLE_DIR" -maxdepth 3 -type f -name 'generate_nm_config' | head -1)"
if [ -z "$gen" ]; then
  warn "No generate_nm_config found under $BUNDLE_DIR."
  echo "" >&2
  if find "$BUNDLE_DIR" -maxdepth 3 -type f -name '*.conf' | grep -q .; then
    warn "There are .conf files there, so this looks like a bundle without the"
    warn "importer. You can still connect directly, per Mozilla's CLI route:"
    while read -r c; do warn "    sudo openvpn --config $c"; done \
      < <(find "$BUNDLE_DIR" -maxdepth 3 -type f -name '*.conf' | sort)
  else
    usage >&2
  fi
  exit 1
fi

gen_dir="$(dirname "$gen")"
chmod u+x "$gen"

# Snapshot the VPN profiles so we can tell which ones the importer added, and
# leave any unrelated VPN alone.
before="$(nmcli -t -f UUID,TYPE connection show | awk -F: '$2 == "vpn" { print $1 }' | sort)"

gen_args=()
[ -z "$DUOTYPE" ] || gen_args+=(--duotype "$DUOTYPE")
[ -z "$FORCE" ] || gen_args+=(--force)

# Upstream takes the config filenames as positional arguments and only falls
# back to globbing its own directory when given none. Pass them explicitly so
# the set processed is the set we staged, and so the run is reproducible.
mapfile -t confs < <(find "$gen_dir" -maxdepth 1 -type f -name 'vpn-config-*.conf' -printf '%f\n' | sort)

say "Running Mozilla's generate_nm_config from $gen_dir…"
if [ "${#gen_args[@]}" -eq 0 ]; then
  echo ""
  echo "    It will ask two questions:"
  echo "      1. push or totp  — choose 'push' if you are unsure; it is the"
  echo "         Duo default and means your password is the literal word 'push'."
  echo "      2. may it modify your NetworkManager config — say yes, otherwise"
  echo "         it only prints the nmcli commands and you run them yourself."
  echo "    Pass MOZVPN_DUOTYPE / MOZVPN_FORCE to answer both up front."
  echo ""
fi

# From its own directory, with stdio passed straight through — with no flags it
# is prompt-driven and must not be piped or captured.
(cd "$gen_dir" && ./generate_nm_config "${gen_args[@]+"${gen_args[@]}"}" ${confs[@]+"${confs[@]}"})

# Re-tighten. This is not belt-and-braces: generate_nm_config rewrites each
# vpn-config-<endpoint>.conf into an openvpn.<host>.ovpn carrying the same
# client private key, and creates it 0664 — world-readable — while the .conf it
# came from is 0400. Observed in the 2026-08-21 bundle via --dry-run. The
# earlier chmod cannot cover files that did not exist yet, so it happens again
# here, after the run.
chmod -R u=rwX,go= "$BUNDLE_DIR"

after="$(nmcli -t -f UUID,TYPE connection show | awk -F: '$2 == "vpn" { print $1 }' | sort)"
mapfile -t new_uuids < <(comm -13 <(echo "$before") <(echo "$after"))

# --- Assertions upstream does not make -------------------------------------

if [ "${#new_uuids[@]}" -eq 0 ]; then
  warn "generate_nm_config added no new VPN profiles."
  warn "    If you answered 'no' to the config question that is expected — run the"
  warn "    nmcli commands it printed, then re-run this script to apply the"
  warn "    hardening below. If you answered 'yes', something went wrong."
  exit 1
fi

say "Imported ${#new_uuids[@]} profile(s). Applying local policy…"
for uuid in "${new_uuids[@]}"; do
  name="$(nmcli -g connection.id connection show uuid "$uuid")"

  # Split tunnel. Upstream already sets both of these, so this is a re-assertion
  # rather than a fix — kept because it is idempotent, costs nothing, and the
  # failure it guards against is silent: a profile that took the default route
  # would put all your traffic and DNS through Mozilla, and the first sign
  # would be your own browsing showing up in their logs. The configs carry no
  # redirect-gateway today; this is about the day one of them does.
  nmcli connection modify uuid "$uuid" ipv4.never-default yes ipv6.never-default yes

  # Never dial automatically. A work VPN with access control behind it should
  # not be coming up on every network you join.
  nmcli connection modify uuid "$uuid" connection.autoconnect no

  # The Duo lockout backstop. Upstream reads `connect-retry-max` out of the
  # config and passes it through as autoconnect-retries — but if its regex
  # misses, it falls back to 0, and 0 in NM means *retry forever* rather than
  # "do not retry". With four remotes per endpoint that is an unbounded stream
  # of Duo prompts, which is precisely the lockout this is all meant to avoid.
  # -1 is NM's global default of 4, also more than we want. So: check rather
  # than assume, and only clamp when the value is one of the bad ones.
  retries="$(nmcli -g connection.autoconnect-retries connection show uuid "$uuid" 2>/dev/null || echo "")"
  if [ -z "$retries" ] || [ "$retries" = "0" ] || [ "$retries" = "-1" ]; then
    warn "$name: autoconnect-retries=${retries:-unset} — setting to 1 to match"
    warn "    the bundle's connect-retry-max and keep Duo from locking you out."
    nmcli connection modify uuid "$uuid" connection.autoconnect-retries 1
  fi

  echo "    $name"
done

# MDC2 (US-East / Virginia) was decommissioned in April 2021. Current bundles
# should not contain it, but an older profile can survive on the machine and
# connecting to it just hangs.
while read -r stale; do
  [ -n "$stale" ] || continue
  warn "Removing decommissioned MDC2 profile: $stale"
  nmcli connection delete id "$stale" >/dev/null
done < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null |
  awk -F: '$2 == "vpn" { print $1 }' | grep -i 'mdc2' || true)

# --- Report ----------------------------------------------------------------

echo ""
say "Done."
echo ""
echo "    Connect (endpoint is required — see 'mozvpn help' for why):"
echo "      mozvpn up mdc1        # US-West / California"
echo "      mozvpn up ber3        # EU-Central / Berlin"
echo "      mozvpn status"
echo "      mozvpn down"
echo ""
echo "    Or click the profile in GNOME's quick settings. You should get a"
echo "    'VPN Login Message' within a few seconds on success."
echo ""
echo "    Credentials, if you are prompted:"
echo "      username: your LDAP address, <you>@mozilla.com"
echo "      password: the literal string 'push' (NOT your LDAP password),"
echo "                or your TOTP code if you chose totp above"
echo ""
# The NM OpenVPN importer copies the CA, cert, key and tls-auth blobs out of
# the .ovpn into its own cert store and points the profile at those, so the
# staged bundle is a redundant second copy of your private key rather than
# something the tunnel depends on. Upstream says as much on exit. Kept anyway
# so a re-import does not need a fresh download — but say plainly that it is
# deletable, because a spare copy of a private key you believe to be
# load-bearing is one you will never get rid of.
echo "    Key material in use by NetworkManager:"
echo "      ~/.local/share/networkmanagement/certificates/nm-openvpn/ (0600)"
echo ""
echo "    The staged bundle in $BUNDLE_DIR is a redundant copy,"
echo "    kept only so a re-import needs no fresh download. Safe to remove:"
echo "      rm -rf $BUNDLE_DIR"
echo "    Never commit it, and mind the original zip in ~/Downloads too."
echo ""
echo "    If you hit AUTH_FAILED, 'mozvpn report' collects everything"
echo "    #servicedesk asks for in one go."
echo ""
