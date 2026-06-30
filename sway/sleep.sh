#!/usr/bin/env sh
# Lock the screen, then sleep — choosing the best mode for THIS host so
# one shared Sway config behaves correctly on every machine.
#
#   * Laptop with real disk-backed swap (a swapfile or swap partition)
#     AND a hibernate-capable kernel  -> hibernate.
#     This machine is s2idle-only, where plain suspend keeps draining
#     the battery, so we power fully off instead. (Lid-close is handled
#     the same way by a logind drop-in, HandleLidSwitch=hibernate.)
#   * Anything else (e.g. a zram-only desktop) -> plain suspend.
#     zram lives in RAM, so it can't back hibernation anyway.
#
# Detection: the kernel must advertise "disk" in /sys/power/state, and
# there must be at least one swap area that is not a /dev/zram* device.
# Done without `grep -v` so the result can't depend on the grep flavour.

swaylock -f -C "$HOME/.config/swaylock/config" &
sleep 0.3

# Does /sys/power/state list the "disk" (hibernate) state?
can_hibernate=0
if [ -r /sys/power/state ]; then
    read -r _states < /sys/power/state
    case " $_states " in *" disk "*) can_hibernate=1 ;; esac
fi

# Is any active swap a real (non-zram) device? /proc/swaps col 1 = path.
has_disk_swap=0
if awk 'NR>1 && $1 !~ /^\/dev\/zram/ { found=1 } END { exit found?0:1 }' /proc/swaps; then
    has_disk_swap=1
fi

if [ "$can_hibernate" = 1 ] && [ "$has_disk_swap" = 1 ]; then
    exec systemctl hibernate
else
    exec systemctl suspend
fi
