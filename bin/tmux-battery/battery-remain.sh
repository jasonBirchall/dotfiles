#!/usr/bin/env bash
# Remaining battery time for the tmux status line.
#
# Replaces tmux-battery's #{battery_remain}, which is broken on every Linux
# host. Two upstream bugs compound (tmux-battery 2.0.0):
#
#   1. helpers.sh is_wsl() tests /proc/version against *"Linux"*, which every
#      Linux kernel matches. print_battery_remain() checks is_wsl first, so the
#      WSL branch always wins and the acpi/upower paths below it are dead code.
#      Installing acpi therefore does not fix the display.
#   2. That branch runs `find /sys/class/power_supply/*/current_now | tail -n1`,
#      assuming one battery. Machines that expose USB-C PD ports as power
#      supplies (any recent Intel laptop) match those too; tail picks a port
#      reporting current_now=0, and the awk division prints "+inf:-nan:-nan".
#
# Reads sysfs directly, so it needs neither acpi nor upower and behaves the
# same on Fedora and Ubuntu. Prints nothing when there is no battery (desktops)
# so the status line simply collapses.
set -uo pipefail

# The first supply that is a real system battery. type=Battery alone is not
# enough: scope=Device marks peripherals (wireless mice, headsets) that also
# report a percentage, and PD ports report type=Battery with no charge counter.
find_battery() {
  local d
  for d in /sys/class/power_supply/*; do
    [ -r "$d/type" ] || continue
    [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] || continue
    if [ -r "$d/scope" ] && [ "$(cat "$d/scope" 2>/dev/null)" = "Device" ]; then
      continue
    fi
    if [ -r "$d/charge_now" ] || [ -r "$d/energy_now" ]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

read_int() {
  local v
  v=$(cat "$1" 2>/dev/null) || return 1
  [[ "$v" =~ ^-?[0-9]+$ ]] || return 1
  echo "${v#-}" # rate sysfs entries are negative while discharging on some firmware
}

main() {
  local bat status now full rate remaining
  bat=$(find_battery) || exit 0

  status=$(cat "$bat/status" 2>/dev/null || echo Unknown)

  # Charge units (µAh/µA) and energy units (µWh/µW) are mutually exclusive and
  # both cancel out in the division, so either pair gives hours.
  if [ -r "$bat/charge_now" ]; then
    now=$(read_int "$bat/charge_now") || exit 0
    full=$(read_int "$bat/charge_full") || exit 0
    rate=$(read_int "$bat/current_now") || rate=0
  else
    now=$(read_int "$bat/energy_now") || exit 0
    full=$(read_int "$bat/energy_full") || exit 0
    rate=$(read_int "$bat/power_now") || rate=0
  fi

  case "$status" in
    Full)
      echo "charged"
      exit 0
      ;;
    "Not charging")
      echo "on AC"
      exit 0
      ;;
  esac

  # A zero rate is normal and transient: firmware reports it briefly after a
  # plug/unplug, and permanently on some docks. Guard it rather than dividing.
  if [ "${rate:-0}" -le 0 ]; then
    echo "--:--"
    exit 0
  fi

  case "$status" in
    Discharging) remaining=$(awk -v n="$now" -v r="$rate" 'BEGIN{printf "%.4f", n/r}') ;;
    Charging) remaining=$(awk -v f="$full" -v n="$now" -v r="$rate" 'BEGIN{printf "%.4f", (f-n)/r}') ;;
    *)
      echo "--:--"
      exit 0
      ;;
  esac

  # Cap absurd estimates instead of printing them. A near-zero rate yields
  # hundreds of hours, which is noise rather than information.
  awk -v h="$remaining" -v s="$status" 'BEGIN{
    if (h > 99) { printf "--:--"; exit }
    hh = int(h); mm = int((h - hh) * 60 + 0.5)
    if (mm == 60) { hh++; mm = 0 }
    printf "%d:%02d %s", hh, mm, (s == "Charging" ? "to full" : "left")
  }'
}

main
