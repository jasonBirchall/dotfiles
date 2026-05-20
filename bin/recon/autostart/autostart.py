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

import subprocess
from dataclasses import dataclass
from pathlib import Path

from _common import run_cli

SYSTEMCTL_CMD: tuple[str, ...] = (
    "systemctl",
    "list-unit-files",
    "--state=enabled",
    "--no-legend",
    "--no-pager",
)
BASELINE_PATH = Path(__file__).parent / "baseline" / "enabled-services.txt"
DIFF_PATH = Path("/tmp/recon-autostart.diff")


@dataclass(frozen=True, order=True)
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

    def serialize(self) -> str:
        return self.value

    @classmethod
    def deserialize(cls, line: str) -> UnitName:
        return cls(line)


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
    return sorted(units)


def fetch_enabled_units() -> list[UnitName]:
    result = subprocess.run(
        list(SYSTEMCTL_CMD),
        capture_output=True,
        text=True,
        check=True,
    )
    return parse_unit_files(result.stdout)


def main() -> int:
    return run_cli(
        description="Drift detection for enabled system .service units.",
        noun="enabled services",
        baseline_path=BASELINE_PATH,
        diff_path=DIFF_PATH,
        fetch=fetch_enabled_units,
        serialize=UnitName.serialize,
        deserialize=UnitName.deserialize,
    )


if __name__ == "__main__":
    raise SystemExit(main())
