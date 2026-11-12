#!/usr/bin/env bash
# Print the host distro family: fedora | ubuntu | darwin | unknown.
#
# Matching ID_LIKE as well as ID means derivatives work without being enumerated
# (Pop!_OS and Mint report ID_LIKE=ubuntu/debian; Nobara reports fedora).
#
# This lives in a script rather than inline in the Makefile because GNU make's
# $(shell ...) cannot contain an unescaped ')' — make's parser counts parens and
# the first case pattern would close the expansion early.
set -euo pipefail

# macOS has no /etc/os-release; uname is the whole story there.
if [ "$(uname -s)" = Darwin ]; then
  echo darwin
  exit 0
fi

if [ ! -r /etc/os-release ]; then
  echo unknown
  exit 0
fi

# shellcheck disable=SC1091
. /etc/os-release

case " ${ID:-} ${ID_LIKE:-} " in
  *" fedora "* | *" rhel "*) echo fedora ;;
  *" debian "* | *" ubuntu "*) echo ubuntu ;;
  *) echo unknown ;;
esac
