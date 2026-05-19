"""Running-services drift detection.

Reports drift in the set of currently-running ``.service`` units across
both ``systemd --system`` and ``systemd --user`` scopes, against a
tracked baseline. See ``bin/recon/README.md`` for the drift model,
``--bless`` convention, output discipline, and stack.

Relation to autostart
---------------------
- ``autostart`` answers: what's *configured* to start at boot?
  (``systemctl list-unit-files --state=enabled``)
- ``processes`` answers: what's *running right now*?
  (``systemctl list-units --type=service --state=running``)

A service can be enabled but not running (failed, manually stopped),
or running but not enabled (started ad hoc, or pulled in by a
dependency). Both signals matter — keep the tools distinct.

Scope (v1)
----------
``.service`` units in the running state, in both system and user
scopes. Each baseline entry is prefixed with its scope so
``system sshd.service`` and ``user mako.service`` are distinct
even when the name collides.

Excluded as inherently churning:

- DBus session-activated services with session-assigned ids:
  ``dbus-:1.X-org.foo.Bar@N.service``. The ``:1.X`` is a per-session
  connection number that changes every reboot, and these units are
  spawned on-demand by DBus rather than being long-lived services
  worth tracking.

Investigation
-------------
When drift fires and you don't recognise a service:

- ``systemctl status <unit>`` (or ``systemctl --user status <unit>``
  for user-scope) — active state, recent logs, owning cgroup.
- ``systemctl cat <unit>`` — full unit file plus any drop-ins.
- ``systemd-cgls <unit>`` — process tree under that unit.
- ``journalctl -u <unit> --since '1 hour ago'`` (add ``--user`` for
  user-scope) — recent logs in context.
- ``rpm -qf $(systemctl show -p FragmentPath --value <unit>)`` —
  package that installed the unit file (system scope).

For a *removed* unit: it stopped. Check the journal for why before
deciding whether to ``systemctl start`` or accept and bless.

Test seam
---------
``parse_running_services`` is the pure function:
``(str, Scope) -> list[RunningService]``. Fixtures captured per
scope at ``fixtures/{system,user}-running.stdout.txt``. Subprocess
and baseline I/O stay thin around it.

Commands
--------
    systemctl list-units --type=service --state=running --no-legend --no-pager
    systemctl --user list-units --type=service --state=running --no-legend --no-pager
"""

from __future__ import annotations

import argparse
import subprocess
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

SYSTEMCTL_BASE: tuple[str, ...] = (
    "list-units",
    "--type=service",
    "--state=running",
    "--no-legend",
    "--no-pager",
)
BASELINE_PATH = Path(__file__).parent / "baseline" / "running-services.txt"
DIFF_PATH = Path("/tmp/recon-processes.diff")


class Scope(StrEnum):
    SYSTEM = "system"
    USER = "user"


@dataclass(frozen=True, order=True)
class RunningService:
    scope: Scope
    name: str

    def serialize(self) -> str:
        return f"{self.scope} {self.name}"

    @classmethod
    def deserialize(cls, line: str) -> RunningService:
        scope_str, name = line.split(" ", 1)
        return cls(scope=Scope(scope_str), name=name)


@dataclass(frozen=True)
class Drift:
    added: tuple[RunningService, ...]
    removed: tuple[RunningService, ...]

    @property
    def has_drift(self) -> bool:
        return bool(self.added or self.removed)


def parse_running_services(stdout: str, scope: Scope) -> list[RunningService]:
    services: list[RunningService] = []
    for raw in stdout.splitlines():
        line = raw.strip()
        if not line:
            continue
        name = line.split()[0]
        if not name.endswith(".service"):
            continue
        if name.startswith("dbus-:"):
            continue
        services.append(RunningService(scope=scope, name=name))
    return sorted(services)


def diff_services(
    baseline: list[RunningService],
    current: list[RunningService],
) -> Drift:
    base_set = set(baseline)
    curr_set = set(current)
    return Drift(
        added=tuple(sorted(curr_set - base_set)),
        removed=tuple(sorted(base_set - curr_set)),
    )


def read_baseline() -> list[RunningService] | None:
    if not BASELINE_PATH.exists():
        return None
    return [
        RunningService.deserialize(line.strip())
        for line in BASELINE_PATH.read_text().splitlines()
        if line.strip()
    ]


def write_baseline(services: list[RunningService]) -> None:
    BASELINE_PATH.parent.mkdir(parents=True, exist_ok=True)
    BASELINE_PATH.write_text(
        "\n".join(s.serialize() for s in sorted(services)) + "\n",
    )


def fetch_running_services() -> list[RunningService]:
    system_out = subprocess.run(
        ["systemctl", *SYSTEMCTL_BASE],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    user_out = subprocess.run(
        ["systemctl", "--user", *SYSTEMCTL_BASE],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return sorted(
        parse_running_services(system_out, Scope.SYSTEM)
        + parse_running_services(user_out, Scope.USER),
    )


def format_diff(drift: Drift) -> str:
    lines = [f"-{s.serialize()}" for s in drift.removed]
    lines += [f"+{s.serialize()}" for s in drift.added]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Drift detection for running system + user .service units.",
    )
    parser.add_argument(
        "--bless",
        action="store_true",
        help="Overwrite the baseline with current state.",
    )
    args = parser.parse_args()

    current = fetch_running_services()

    if args.bless:
        write_baseline(current)
        print(f"blessed baseline: {len(current)} running services at {BASELINE_PATH}")
        return 0

    baseline = read_baseline()
    if baseline is None:
        write_baseline(current)
        print(f"no baseline found at {BASELINE_PATH}, creating it")
        return 0

    drift = diff_services(baseline, current)
    if not drift.has_drift:
        print(f"no drift ({len(current)} running services)")
        return 0

    DIFF_PATH.write_text(format_diff(drift))
    print(
        f"drift detected: +{len(drift.added)} -{len(drift.removed)} "
        f"(full diff: {DIFF_PATH})",
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
