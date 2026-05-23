"""Outbound destination-port drift detection.

Reports drift in the set of ``(protocol, dest_port)`` pairs the machine
has talked to globally-routable hosts on, against a tracked baseline.
See ``bin/recon/README.md`` for the drift model, ``--bless`` convention,
output discipline, and stack.

Why dest_port and not dest_ip
-----------------------------
Destination IPs churn — CDNs, load balancers, cloud regions all rotate
addresses faster than is useful to track, and a baseline of IPs would
be one continuous false-positive. ``(protocol, dest_port)`` is the
stable unit: ``tcp 443`` is "https traffic", regardless of which AWS
edge served it today. New ports surfacing — ``tcp 6667`` (IRC),
``tcp 4444`` (often Metasploit), ``udp 1900`` (SSDP, may indicate LAN
scanning) — is the actual signal worth alerting on.

Additions-only drift
--------------------
The baseline is sourced from Suricata's ``eve.json``, which is rotated
daily — so the "current" set is really a rolling window of recent
traffic. A port simply not being used in the latest window is not
suspicious: I might not have opened my IRC client this week.
``run_cli(..., additions_only=True)`` suppresses ``removed`` from the
diff for exactly this reason.

Direction (v1 heuristic)
------------------------
Suricata flow events have ``src_ip``/``dest_ip`` but no explicit
direction. We treat a flow as outbound when ``dest_ip`` is globally
routable (``ipaddress.is_global``). This misclassifies inbound scans
from the public internet hitting an open port on this machine — but
in practice that's an entirely separate problem already covered by
the ``listening`` tool, and random IPv6 inbound scanning is
negligible. Revisit if false positives accumulate.

Investigation
-------------
When drift fires and a new ``(proto, port)`` appears:

- ``jq -c 'select(.event_type=="flow" and .proto=="TCP" and .dest_port==PORT)'
  /var/log/suricata/eve.json | head`` — pull recent flows on that port.
- ``ss -tupnH state established '( dport = :PORT )'`` — anything talking
  on that port *right now*, with PID.
- ``getent services PORT`` — what's that port commonly used for?
- Check the rotated ``eve.json-*`` files in ``/var/log/suricata/`` if
  the current window is too narrow.

If you recognise it (new app installed, new service signed up for),
re-bless. If you don't, dig into the destination IPs the flows landed
on (``jq`` as above) and the matching ``dns``/``tls`` events for SNI.

Test seam
---------
Pure parser: ``parse_outbound_ports(str) -> list[OutboundPort]`` consumes
``eve.json`` as a string of JSON lines and applies all filtering. The
subprocess-free design means the fixture at ``fixtures/eve-flows.jsonl``
exercises every filter branch.

Source
------
    /var/log/suricata/eve.json   — see suricata/setup-suricata.sh for
    the logrotate copytruncate config that keeps this file growing.
"""

from __future__ import annotations

import ipaddress
import json
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path

from _common import run_cli

EVE_LOG = Path("/var/log/suricata/eve.json")
BASELINE_PATH = Path(__file__).parent / "baseline" / "outbound-ports.txt"
DIFF_PATH = Path("/tmp/recon-outbound.diff")


class Protocol(StrEnum):
    TCP = "tcp"
    UDP = "udp"


@dataclass(frozen=True, order=True)
class OutboundPort:
    protocol: Protocol
    port: int

    def serialize(self) -> str:
        return f"{self.protocol} {self.port}"

    @classmethod
    def deserialize(cls, line: str) -> OutboundPort:
        proto_str, port_str = line.split(" ", 1)
        return cls(protocol=Protocol(proto_str), port=int(port_str))


def parse_outbound_ports(eve_lines: str) -> list[OutboundPort]:
    seen: set[OutboundPort] = set()
    for raw in eve_lines.splitlines():
        line = raw.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("event_type") != "flow":
            continue
        proto = event.get("proto")
        if proto not in ("TCP", "UDP"):
            continue
        dest_port = event.get("dest_port")
        if not isinstance(dest_port, int):
            continue
        dest_ip = event.get("dest_ip")
        if not isinstance(dest_ip, str) or not _is_global(dest_ip):
            continue
        seen.add(OutboundPort(protocol=Protocol(proto.lower()), port=dest_port))
    return sorted(seen)


def _is_global(ip: str) -> bool:
    try:
        return ipaddress.ip_address(ip).is_global
    except ValueError:
        return False


def fetch_outbound_ports() -> list[OutboundPort]:
    return parse_outbound_ports(EVE_LOG.read_text())


def main() -> int:
    return run_cli(
        description="Drift detection for outbound (protocol, dest_port) pairs.",
        noun="outbound ports",
        baseline_path=BASELINE_PATH,
        diff_path=DIFF_PATH,
        fetch=fetch_outbound_ports,
        serialize=OutboundPort.serialize,
        deserialize=OutboundPort.deserialize,
        additions_only=True,
    )


if __name__ == "__main__":
    raise SystemExit(main())
