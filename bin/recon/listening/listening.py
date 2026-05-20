"""Listening-sockets drift detection.

Reports drift in local TCP + UDP listeners against a tracked baseline.
See ``bin/recon/README.md`` for the drift model, ``--bless`` convention,
output discipline, and stack.

Scope (v1)
----------
TCP + UDP listeners bound to one of:

- ``0.0.0.0`` or ``[::]``  — exposed on all interfaces
- ``127.0.0.0/8`` or ``[::1]`` — loopback

Everything else is excluded as inherently noisy or transient:

- Wildcard ``*:port`` — UDP client-style sockets, not real listeners.
- IPv6 link-local ``fe80::*`` — interface-bound, churn on network change.
- Multicast (``224.0.0.0/4`` and ``ff00::/8``) — mDNS / SSDP / LLMNR joiners.
- Specific-IP listeners (e.g. bound to your current LAN address) —
  drift would fire every time DHCP changes the IP. If you ever need
  to track these, v2 should normalise the IP to a stable marker.

Investigation
-------------
When drift fires and you don't recognise an added listener:

- ``sudo ss -tulpnH sport = :<port>`` — full row including PID and
  program name for that port.
- ``sudo lsof -nP -iTCP:<port>`` (or ``-iUDP:<port>``) — which process
  holds the socket and what else it has open.
- ``systemctl status <unit>`` if you can guess the unit, otherwise
  ``systemctl list-units --type=service --state=running``.
- ``rpm -qf $(realpath /proc/<PID>/exe)`` — package that owns the
  binary holding the socket.

Test seam
---------
``parse_listeners`` is the pure function: ``str -> list[Listener]``
(``ss -tulnH`` stdout to a sorted, post-filter list).
``fixtures/listeners.stdout.txt`` is the captured input. Subprocess
and baseline I/O stay thin around it.

Command
-------
    ss -tulnH
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

from _common import run_cli

SS_CMD: tuple[str, ...] = ("ss", "-tulnH")
BASELINE_PATH = Path(__file__).parent / "baseline" / "listeners.txt"
DIFF_PATH = Path("/tmp/recon-listening.diff")

LOOPBACK_V6 = "[::1]"
EXPOSED_V4 = "0.0.0.0"
EXPOSED_V6 = "[::]"


class Protocol(StrEnum):
    TCP = "tcp"
    UDP = "udp"


class Scope(StrEnum):
    EXPOSED = "exposed"
    LOOPBACK = "loopback"


@dataclass(frozen=True, order=True)
class Listener:
    scope: Scope
    protocol: Protocol
    address: str
    port: int

    def serialize(self) -> str:
        return f"{self.scope} {self.protocol} {self.address}:{self.port}"

    @classmethod
    def deserialize(cls, line: str) -> Listener:
        scope_str, proto_str, addr_port = line.split(" ", 2)
        addr, port_str = addr_port.rsplit(":", 1)
        return cls(
            scope=Scope(scope_str),
            protocol=Protocol(proto_str),
            address=addr,
            port=int(port_str),
        )


def parse_listeners(stdout: str) -> list[Listener]:
    seen: set[Listener] = set()
    for raw in stdout.splitlines():
        line = raw.strip()
        if not line:
            continue
        fields = line.split()
        if len(fields) < 5:
            continue
        proto_str = fields[0]
        if proto_str not in {p.value for p in Protocol}:
            continue
        listener = _make_listener(proto_str, fields[4])
        if listener is not None:
            seen.add(listener)
    return sorted(seen)


def fetch_listeners() -> list[Listener]:
    result = subprocess.run(
        list(SS_CMD),
        capture_output=True,
        text=True,
        check=True,
    )
    return parse_listeners(result.stdout)


def main() -> int:
    return run_cli(
        description="Drift detection for local TCP+UDP listeners.",
        noun="listeners",
        baseline_path=BASELINE_PATH,
        diff_path=DIFF_PATH,
        fetch=fetch_listeners,
        serialize=Listener.serialize,
        deserialize=Listener.deserialize,
    )


def _make_listener(proto_str: str, local: str) -> Listener | None:
    addr, port = _split_addr_port(local)
    if addr is None or port is None:
        return None
    addr = _strip_interface_suffix(addr)
    scope = _classify_scope(addr)
    if scope is None:
        return None
    return Listener(
        scope=scope,
        protocol=Protocol(proto_str),
        address=addr,
        port=port,
    )


def _split_addr_port(s: str) -> tuple[str | None, int | None]:
    if s.startswith("["):
        bracket_end = s.find("]")
        if bracket_end == -1 or ":" not in s[bracket_end + 1:]:
            return None, None
        addr = s[: bracket_end + 1]
        port_str = s[bracket_end + 1:].rsplit(":", 1)[1]
    else:
        if ":" not in s:
            return None, None
        addr, port_str = s.rsplit(":", 1)
    try:
        return addr, int(port_str)
    except ValueError:
        return None, None


def _strip_interface_suffix(addr: str) -> str:
    if "%" in addr:
        head, _, _ = addr.partition("%")
        if addr.endswith("]"):
            return head + "]"
        return head
    return addr


def _classify_scope(addr: str) -> Scope | None:
    if addr == EXPOSED_V4 or addr == EXPOSED_V6:
        return Scope.EXPOSED
    if addr == LOOPBACK_V6:
        return Scope.LOOPBACK
    if addr.startswith("127."):
        return Scope.LOOPBACK
    return None


if __name__ == "__main__":
    raise SystemExit(main())
