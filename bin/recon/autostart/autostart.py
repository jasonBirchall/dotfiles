"""Autostart drift detection.

Reports drift in enabled systemd units (system scope) against a tracked
baseline. See ``bin/recon/README.md`` for the drift model, first-run
behaviour, ``--bless`` convention, output discipline, and stack.

Scope (v1)
----------
Enabled system ``.service`` units only — most stable, highest signal.
Deferred until this is working end-to-end:

- Other unit types in system scope (``.timer``, ``.socket``, ``.path``,
  ``.target``, ``.mount``)
- User-scope units (``systemctl --user list-unit-files``)
- Timers (``systemctl list-timers --all``)
- Cron (``/etc/cron.d/``, ``/etc/cron.{hourly,daily,weekly,monthly}/``,
  user crontabs, root crontab)
- Desktop autostart (``~/.config/autostart/``, ``/etc/xdg/autostart/``)

Shell init (``~/.bashrc`` and friends) is **excluded** from this tool —
it's content-level, not list-membership, and doesn't fit the diff
pattern. If ever covered, it needs file-content hashing rather than
list comparison.

Known gap
---------
List-membership only. If a unit is enabled in both baseline and current
but its file contents change (different ``ExecStart=``, new
``EnvironmentFile=``, etc.), this tool will not see it. Closing that
gap means hashing unit-file contents — deferred.

Investigation
-------------
When drift fires and you don't recognise an added unit:

- ``systemctl status <unit>`` — active state, last log lines, owning
  cgroup. First stop.
- ``systemctl cat <unit>`` — full unit-file content, including any
  drop-ins under ``/etc/systemd/system/<unit>.d/``.
- ``rpm -qf $(systemctl show -p FragmentPath --value <unit>)`` —
  package that installed the unit file. ``rpm: not owned`` means it
  was put there by hand or by a non-RPM installer — read it carefully.
- ``systemctl disable --now <unit>`` — stop and remove from the
  enabled set. Re-run autostart with no ``--bless`` to confirm it's
  back to baseline.

For a removed unit, swap "added" for "removed" and ``enable`` for
``disable``. Either way: confirm against ``baseline/enabled-services.txt``
before blessing.

Test seam
---------
``parse_unit_files`` is the pure function: ``str -> list[UnitName]``
(systemctl stdout to sorted unit names). ``fixtures/system-units.stdout.txt``
is the captured real output to test against. The subprocess call and the
baseline file I/O stay thin around it.

Command
-------
    systemctl list-unit-files --state=enabled --no-legend --no-pager
"""

from __future__ import annotations

import argparse
import subprocess
from dataclasses import dataclass
from pathlib import Path

SYSTEMCTL_CMD: tuple[str, ...] = (
    "systemctl",
    "list-unit-files",
    "--state=enabled",
    "--no-legend",
    "--no-pager",
)
BASELINE_PATH = Path(__file__).parent / "baseline" / "enabled-services.txt"
DIFF_PATH = Path("/tmp/recon-autostart.diff")


@dataclass(frozen=True)
class UnitName:
    value: str

    def __post_init__(self) -> None:
        if self.value == "":
            raise ValueError("Unit name cannot be empty")

        if self.value.count(".") != 1:
            raise ValueError(f"Unit name '{self.value}' does not have exactly one dot")

        suffix = self.value.split(".")[1]
        if suffix != "service":
            raise ValueError(f"Unit name suffix '{suffix}' is not valid")


@dataclass(frozen=True)
class Drift:
    added: tuple[UnitName, ...]
    removed: tuple[UnitName, ...]

    @property
    def has_drift(self) -> bool:
        return bool(self.added or self.removed)


def parse_unit_files(stdout: str) -> list[UnitName]:
    """Parse ``systemctl list-unit-files`` output to sorted ``.service`` names.

    Non-service unit types are dropped — v1 scope (see module docstring).
    """
    units: list[UnitName] = []
    for raw_line in stdout.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        name = line.split()[0]
        if not name.endswith(".service"):
            continue
        units.append(UnitName(name))
    return sorted(units, key=_by_value)


def diff_units(baseline: list[UnitName], current: list[UnitName]) -> Drift:
    base_set = set(baseline)
    curr_set = set(current)
    return Drift(
        added=tuple(sorted(curr_set - base_set, key=_by_value)),
        removed=tuple(sorted(base_set - curr_set, key=_by_value)),
    )


def read_baseline() -> list[UnitName] | None:
    if not BASELINE_PATH.exists():
        return None
    return [
        UnitName(line.strip())
        for line in BASELINE_PATH.read_text().splitlines()
        if line.strip()
    ]


def write_baseline(units: list[UnitName]) -> None:
    BASELINE_PATH.parent.mkdir(parents=True, exist_ok=True)
    sorted_units = sorted(units, key=_by_value)
    BASELINE_PATH.write_text("\n".join(u.value for u in sorted_units) + "\n")


def fetch_enabled_units() -> list[UnitName]:
    result = subprocess.run(
        list(SYSTEMCTL_CMD),
        capture_output=True,
        text=True,
        check=True,
    )
    return parse_unit_files(result.stdout)


def format_diff(drift: Drift) -> str:
    lines = [f"-{u.value}" for u in drift.removed]
    lines += [f"+{u.value}" for u in drift.added]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Drift detection for enabled system .service units.",
    )
    parser.add_argument(
        "--bless",
        action="store_true",
        help="Overwrite the baseline with current state.",
    )
    args = parser.parse_args()

    current = fetch_enabled_units()

    if args.bless:
        write_baseline(current)
        print(f"blessed baseline: {len(current)} enabled services at {BASELINE_PATH}")
        return 0

    baseline = read_baseline()
    if baseline is None:
        write_baseline(current)
        print(f"no baseline found at {BASELINE_PATH}, creating it")
        return 0

    drift = diff_units(baseline, current)
    if not drift.has_drift:
        print(f"no drift ({len(current)} enabled services)")
        return 0

    DIFF_PATH.write_text(format_diff(drift))
    print(
        f"drift detected: +{len(drift.added)} -{len(drift.removed)} "
        f"(full diff: {DIFF_PATH})",
    )
    return 1


def _by_value(unit: UnitName) -> str:
    return unit.value


if __name__ == "__main__":
    raise SystemExit(main())
