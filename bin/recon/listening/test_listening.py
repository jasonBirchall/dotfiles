from pathlib import Path

from _common import Drift, diff
from listening.listening import (
    Listener,
    Protocol,
    Scope,
    parse_listeners,
)


def diff_listeners(
    baseline: list[Listener], current: list[Listener]
) -> Drift[Listener]:
    return diff(baseline, current)


FIXTURES = Path(__file__).parent / "fixtures"


def make(scope: Scope, proto: Protocol, address: str, port: int) -> Listener:
    return Listener(scope=scope, protocol=proto, address=address, port=port)


class TestListenerSerialize:
    def test_roundtrip_ipv4(self):
        listener = make(Scope.LOOPBACK, Protocol.TCP, "127.0.0.1", 631)

        assert Listener.deserialize(listener.serialize()) == listener

    def test_roundtrip_ipv6(self):
        listener = make(Scope.EXPOSED, Protocol.UDP, "[::]", 5353)

        assert Listener.deserialize(listener.serialize()) == listener

    def test_serialise_format_is_space_separated(self):
        line = make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 22).serialize()

        assert line == "exposed tcp 0.0.0.0:22"


class TestParseListeners:
    def test_returns_empty_list_for_empty_input(self):
        assert parse_listeners("") == []

    def test_ignores_blank_lines(self):
        assert parse_listeners("\n   \n\n") == []

    def test_parses_basic_ipv4_tcp_listener(self):
        stdout = "tcp LISTEN 0 4096 127.0.0.1:631 0.0.0.0:*\n"

        assert parse_listeners(stdout) == [
            make(Scope.LOOPBACK, Protocol.TCP, "127.0.0.1", 631)
        ]

    def test_parses_basic_ipv4_udp_listener(self):
        stdout = "udp UNCONN 0 0 0.0.0.0:5353 0.0.0.0:*\n"

        assert parse_listeners(stdout) == [
            make(Scope.EXPOSED, Protocol.UDP, "0.0.0.0", 5353)
        ]

    def test_parses_ipv6_loopback(self):
        stdout = "tcp LISTEN 0 4096 [::1]:631 [::]:*\n"

        assert parse_listeners(stdout) == [
            make(Scope.LOOPBACK, Protocol.TCP, "[::1]", 631)
        ]

    def test_parses_ipv6_exposed(self):
        stdout = "udp UNCONN 0 0 [::]:5353 [::]:*\n"

        assert parse_listeners(stdout) == [
            make(Scope.EXPOSED, Protocol.UDP, "[::]", 5353)
        ]

    def test_treats_full_127_subnet_as_loopback(self):
        stdout = (
            "udp UNCONN 0 0 127.0.0.53:53 0.0.0.0:*\n"
            "udp UNCONN 0 0 127.0.0.54:53 0.0.0.0:*\n"
        )

        listeners = parse_listeners(stdout)

        assert all(ln.scope == Scope.LOOPBACK for ln in listeners)

    def test_strips_interface_suffix_from_ipv4(self):
        stdout = "udp UNCONN 0 0 127.0.0.53%lo:53 0.0.0.0:*\n"

        assert parse_listeners(stdout) == [
            make(Scope.LOOPBACK, Protocol.UDP, "127.0.0.53", 53)
        ]

    def test_filters_wildcard_local_address(self):
        stdout = "udp UNCONN 0 0 *:41961 *:*\n"

        assert parse_listeners(stdout) == []

    def test_filters_link_local_ipv6(self):
        stdout = "udp UNCONN 0 0 [fe80::abcd]%wlp5s0:3702 [::]:*\n"

        assert parse_listeners(stdout) == []

    def test_filters_ipv6_multicast(self):
        stdout = "udp UNCONN 0 0 [ff02::c]%wlp5s0:3702 [::]:*\n"

        assert parse_listeners(stdout) == []

    def test_filters_ipv4_multicast(self):
        stdout = "udp UNCONN 0 0 239.255.255.250:3702 0.0.0.0:*\n"

        assert parse_listeners(stdout) == []

    def test_filters_specific_lan_ip(self):
        stdout = "udp UNCONN 0 0 192.168.1.224:3702 0.0.0.0:*\n"

        assert parse_listeners(stdout) == []

    def test_deduplicates_identical_listeners(self):
        stdout = (
            "tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*\n"
            "tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*\n"
        )

        assert parse_listeners(stdout) == [
            make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 22)
        ]

    def test_result_is_sorted(self):
        stdout = (
            "tcp LISTEN 0 4096 127.0.0.1:631 0.0.0.0:*\n"
            "tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*\n"
            "udp UNCONN 0 0 0.0.0.0:5353 0.0.0.0:*\n"
        )

        listeners = parse_listeners(stdout)

        assert listeners == sorted(listeners)

    def test_skips_unknown_protocols(self):
        stdout = "raw UNCONN 0 0 0.0.0.0:1 0.0.0.0:*\n"

        assert parse_listeners(stdout) == []

    def test_filters_ephemeral_udp_port(self):
        stdout = "udp UNCONN 0 0 0.0.0.0:45000 0.0.0.0:*\n"

        assert parse_listeners(stdout, ephemeral_min=32768) == []

    def test_keeps_udp_port_just_below_ephemeral_range(self):
        stdout = "udp UNCONN 0 0 0.0.0.0:32767 0.0.0.0:*\n"

        assert parse_listeners(stdout, ephemeral_min=32768) == [
            make(Scope.EXPOSED, Protocol.UDP, "0.0.0.0", 32767)
        ]

    def test_filters_udp_port_exactly_at_ephemeral_min(self):
        stdout = "udp UNCONN 0 0 0.0.0.0:32768 0.0.0.0:*\n"

        assert parse_listeners(stdout, ephemeral_min=32768) == []

    def test_keeps_high_tcp_port(self):
        # The ephemeral filter is UDP-only; a high TCP port is usually
        # a deliberate service.
        stdout = "tcp LISTEN 0 4096 0.0.0.0:45000 0.0.0.0:*\n"

        assert parse_listeners(stdout, ephemeral_min=32768) == [
            make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 45000)
        ]

    def test_parses_real_ss_fixture(self):
        stdout = (FIXTURES / "listeners.stdout.txt").read_text()

        listeners = parse_listeners(stdout)

        # Every surviving listener has a non-empty address and a port > 0
        assert all(ln.address and ln.port > 0 for ln in listeners)
        # Filters worked — none of the noisy categories survive
        assert not any("fe80" in ln.address for ln in listeners)
        assert not any("ff02" in ln.address for ln in listeners)
        assert not any(ln.address.startswith("192.0.2.") for ln in listeners)
        assert not any(ln.address == "*" for ln in listeners)
        # The fixture's avahi ephemeral UDP port (0.0.0.0:41583) is gone
        assert not any(
            ln.protocol is Protocol.UDP and ln.port >= 32768 for ln in listeners
        )
        # A handful of expected entries from the fixture
        assert make(Scope.LOOPBACK, Protocol.TCP, "127.0.0.1", 631) in listeners
        assert make(Scope.EXPOSED, Protocol.UDP, "0.0.0.0", 5353) in listeners
        assert make(Scope.EXPOSED, Protocol.UDP, "[::]", 5353) in listeners


class TestDiffListeners:
    def test_no_drift_when_baseline_equals_current(self):
        baseline = [
            make(Scope.LOOPBACK, Protocol.TCP, "127.0.0.1", 631),
            make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 22),
        ]
        current = list(reversed(baseline))

        drift = diff_listeners(baseline, current)

        assert drift == Drift(added=(), removed=())
        assert drift.has_drift is False

    def test_detects_added_listener(self):
        baseline = [make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 22)]
        added = make(Scope.LOOPBACK, Protocol.TCP, "127.0.0.1", 11434)
        current = baseline + [added]

        drift = diff_listeners(baseline, current)

        assert drift.added == (added,)
        assert drift.removed == ()
        assert drift.has_drift is True

    def test_detects_removed_listener(self):
        removed = make(Scope.LOOPBACK, Protocol.TCP, "127.0.0.1", 631)
        baseline = [removed, make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 22)]
        current = [make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 22)]

        drift = diff_listeners(baseline, current)

        assert drift.added == ()
        assert drift.removed == (removed,)

    def test_detects_protocol_or_scope_change_as_independent_entries(self):
        # Same address+port across tcp/udp are different listeners
        baseline = [make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 5353)]
        current = [make(Scope.EXPOSED, Protocol.UDP, "0.0.0.0", 5353)]

        drift = diff_listeners(baseline, current)

        assert drift.added == (make(Scope.EXPOSED, Protocol.UDP, "0.0.0.0", 5353),)
        assert drift.removed == (make(Scope.EXPOSED, Protocol.TCP, "0.0.0.0", 5353),)
