"""Autostart drift detection.

Reports drift in enabled systemd units (system scope) against a tracked
baseline. See ``bin/recon/README.md`` for the drift model, first-run
behaviour, ``--bless`` convention, output discipline, and stack.

Scope (v1)
----------
Enabled system units only — most stable, highest signal. Deferred until
this is working end-to-end:

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

Test seam
---------
Keep parsing as a pure function: ``str -> list[str]`` (systemctl stdout
to sorted unit names). Capture real output as
``fixtures/system-units.stdout.txt`` and pytest against that. The
subprocess call and the baseline file I/O stay thin.

Candidate command
-----------------
    systemctl list-unit-files --state=enabled --no-legend --no-pager
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class UnitName:
    value: str

    def __post_init__(self) -> None:
        if self.value == "":
            raise ValueError("Unit name cannot be empty")

        # check if value has a suffix (e.g. "foo.service")
        if self.value.split(".")[-1] == self.value:
            raise ValueError(f"Unit name '{self.value}' does not have a suffix")

        suffix = self.value.split(".")[1]

        if suffix != "service":
            raise ValueError(f"Unit name suffix '{suffix}' is not valid")
