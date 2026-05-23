from pathlib import Path

from _common import Drift, diff
from outbound.outbound import (
    OutboundPort,
    Protocol,
    parse_outbound_ports,
)


def diff_ports(
    baseline: list[OutboundPort], current: list[OutboundPort]
) -> Drift[OutboundPort]:
    return diff(baseline, current)


FIXTURES = Path(__file__).parent / "fixtures"


def port(proto: Protocol, num: int) -> OutboundPort:
    return OutboundPort(protocol=proto, port=num)


class TestOutboundPortSerialize:
    def test_roundtrip_tcp(self):
        p = port(Protocol.TCP, 443)

        assert OutboundPort.deserialize(p.serialize()) == p

    def test_roundtrip_udp(self):
        p = port(Protocol.UDP, 53)

        assert OutboundPort.deserialize(p.serialize()) == p

    def test_serialise_format_is_space_separated(self):
        assert port(Protocol.TCP, 443).serialize() == "tcp 443"


class TestParseOutboundPorts:
    def test_returns_empty_list_for_empty_input(self):
        assert parse_outbound_ports("") == []

    def test_ignores_blank_lines(self):
        assert parse_outbound_ports("\n   \n\n") == []

    def test_skips_malformed_json(self):
        assert parse_outbound_ports("not valid json\n{also bad\n") == []

    def test_keeps_tcp_flow_to_global_dest(self):
        line = (
            '{"event_type":"flow","proto":"TCP",'
            '"dest_ip":"1.1.1.1","dest_port":443}'
        )

        assert parse_outbound_ports(line) == [port(Protocol.TCP, 443)]

    def test_keeps_udp_flow_to_global_dest(self):
        line = (
            '{"event_type":"flow","proto":"UDP",'
            '"dest_ip":"8.8.8.8","dest_port":53}'
        )

        assert parse_outbound_ports(line) == [port(Protocol.UDP, 53)]

    def test_filters_private_ipv4_dest(self):
        line = (
            '{"event_type":"flow","proto":"TCP",'
            '"dest_ip":"192.168.1.1","dest_port":53}'
        )

        assert parse_outbound_ports(line) == []

    def test_filters_loopback_dest(self):
        line = (
            '{"event_type":"flow","proto":"TCP",'
            '"dest_ip":"127.0.0.1","dest_port":5432}'
        )

        assert parse_outbound_ports(line) == []

    def test_filters_link_local_dest(self):
        line = (
            '{"event_type":"flow","proto":"TCP",'
            '"dest_ip":"169.254.169.254","dest_port":80}'
        )

        assert parse_outbound_ports(line) == []

    def test_filters_non_flow_event_types(self):
        line = (
            '{"event_type":"dns","proto":"UDP",'
            '"dest_ip":"8.8.8.8","dest_port":53}'
        )

        assert parse_outbound_ports(line) == []

    def test_filters_icmp_with_no_port(self):
        line = (
            '{"event_type":"flow","proto":"ICMP","dest_ip":"1.1.1.1"}'
        )

        assert parse_outbound_ports(line) == []

    def test_filters_flow_with_missing_dest_port(self):
        line = (
            '{"event_type":"flow","proto":"TCP","dest_ip":"1.1.1.1"}'
        )

        assert parse_outbound_ports(line) == []

    def test_filters_flow_with_missing_dest_ip(self):
        line = '{"event_type":"flow","proto":"TCP","dest_port":443}'

        assert parse_outbound_ports(line) == []

    def test_filters_flow_with_unparseable_dest_ip(self):
        line = (
            '{"event_type":"flow","proto":"TCP",'
            '"dest_ip":"not-an-ip","dest_port":443}'
        )

        assert parse_outbound_ports(line) == []

    def test_keeps_global_ipv6_dest(self):
        line = (
            '{"event_type":"flow","proto":"TCP",'
            '"dest_ip":"2606:4700::1111","dest_port":443}'
        )

        assert parse_outbound_ports(line) == [port(Protocol.TCP, 443)]

    def test_deduplicates_repeated_pairs(self):
        lines = "\n".join(
            [
                '{"event_type":"flow","proto":"TCP","dest_ip":"1.1.1.1","dest_port":443}',
                '{"event_type":"flow","proto":"TCP","dest_ip":"8.8.8.8","dest_port":443}',
            ]
        )

        assert parse_outbound_ports(lines) == [port(Protocol.TCP, 443)]

    def test_sorts_by_protocol_then_port(self):
        lines = "\n".join(
            [
                '{"event_type":"flow","proto":"UDP","dest_ip":"1.1.1.1","dest_port":53}',
                '{"event_type":"flow","proto":"TCP","dest_ip":"1.1.1.1","dest_port":443}',
                '{"event_type":"flow","proto":"TCP","dest_ip":"1.1.1.1","dest_port":80}',
            ]
        )

        assert parse_outbound_ports(lines) == [
            port(Protocol.TCP, 80),
            port(Protocol.TCP, 443),
            port(Protocol.UDP, 53),
        ]

    def test_parses_real_fixture(self):
        raw = (FIXTURES / "eve-flows.jsonl").read_text()

        ports = parse_outbound_ports(raw)

        # Fixture has TCP/443 (x2, deduped), UDP/53 to 8.8.8.8, TCP/6667,
        # and an IPv6 TCP/443 — all global, all kept.
        assert ports == [
            port(Protocol.TCP, 443),
            port(Protocol.TCP, 6667),
            port(Protocol.UDP, 53),
        ]


class TestDiffPorts:
    def test_no_drift_when_baseline_equals_current(self):
        baseline = [port(Protocol.TCP, 443), port(Protocol.UDP, 53)]
        current = list(reversed(baseline))

        drift = diff_ports(baseline, current)

        assert drift == Drift(added=(), removed=())
        assert drift.has_drift is False

    def test_detects_added_port(self):
        baseline = [port(Protocol.TCP, 443)]
        added = port(Protocol.TCP, 6667)
        current = baseline + [added]

        drift = diff_ports(baseline, current)

        assert drift.added == (added,)
        assert drift.removed == ()

    def test_treats_same_port_different_proto_as_distinct(self):
        baseline = [port(Protocol.TCP, 53)]
        current = [port(Protocol.TCP, 53), port(Protocol.UDP, 53)]

        drift = diff_ports(baseline, current)

        assert drift.added == (port(Protocol.UDP, 53),)
        assert drift.removed == ()
