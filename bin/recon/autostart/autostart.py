"""Autostart drift detection.

What runs at boot or on a schedule, and where does it come from?
This tool answers: "compared to what I last blessed, what's changed?"

Surface (v1)
------------
Enabled system units only — most stable, highest signal. Other surfaces
(user units, timers, cron, desktop autostart) are deliberately out of
scope until this one's working end-to-end. Add them as separate baselines
once the workflow is settled.

Drift model
-----------
- Baseline: a sorted list of enabled unit names at
  ``bin/recon/autostart/baseline/system-units.txt`` (gitignored).
- Each run computes the current list and reports additions/removals
  vs the baseline. Re-blessing is an explicit action (e.g. a ``--bless``
  flag), never automatic.

First-run behaviour
-------------------
Decision still pending — refuse with an ``--init`` hint, or auto-create
on first run? Pick one and apply it consistently across recon tools so
future-you doesn't have to remember which is which.

Test seam
---------
The interesting parsing is "given systemctl stdout, return a sorted list
of enabled unit names." Keep that as a pure function (no I/O, no
subprocess) so it can be fed captured fixtures from ``fixtures/`` under
pytest. The subprocess call and the baseline file I/O around it should
stay thin — they're not what you're testing.

Path handling
-------------
Resolve the baseline path relative to ``__file__``, not cwd. ``make``
runs scripts from the repo root via ``uv run --directory``, so cwd is
not the script's directory and paths break otherwise.

Candidate command for v1
------------------------
    systemctl list-unit-files --state=enabled --no-legend --no-pager

Other surfaces, for later (do not implement now):
    systemctl --user list-unit-files --state=enabled
    systemctl list-timers --all
    crontab -l ; sudo crontab -l
    ls /etc/cron.d/ /etc/cron.{hourly,daily,weekly,monthly}/
    ls ~/.config/autostart/ /etc/xdg/autostart/
"""


def main() -> None:
    print("TODO: implement autostart drift detection")


if __name__ == "__main__":
    main()
