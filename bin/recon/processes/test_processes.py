from pathlib import Path

from processes import (
    Drift,
    RunningService,
    Scope,
    diff_services,
    parse_running_services,
)

FIXTURES = Path(__file__).parent / "fixtures"


def svc(scope: Scope, name: str) -> RunningService:
    return RunningService(scope=scope, name=name)


class TestRunningServiceSerialize:
    def test_roundtrip_system(self):
        s = svc(Scope.SYSTEM, "sshd.service")

        assert RunningService.deserialize(s.serialize()) == s

    def test_roundtrip_user(self):
        s = svc(Scope.USER, "mako.service")

        assert RunningService.deserialize(s.serialize()) == s

    def test_serialise_format_is_space_separated(self):
        assert svc(Scope.SYSTEM, "sshd.service").serialize() == "system sshd.service"


class TestParseRunningServices:
    def test_returns_empty_list_for_empty_input(self):
        assert parse_running_services("", Scope.SYSTEM) == []

    def test_ignores_blank_lines(self):
        stdout = "\n   \n\n"

        assert parse_running_services(stdout, Scope.SYSTEM) == []

    def test_parses_basic_running_service(self):
        stdout = "  sshd.service loaded active running OpenSSH daemon\n"

        assert parse_running_services(stdout, Scope.SYSTEM) == [
            svc(Scope.SYSTEM, "sshd.service")
        ]

    def test_drops_non_service_unit_types(self):
        stdout = (
            "  sshd.service loaded active running OpenSSH daemon\n"
            "  graphical.target loaded active active Graphical Interface\n"
        )

        assert parse_running_services(stdout, Scope.SYSTEM) == [
            svc(Scope.SYSTEM, "sshd.service")
        ]

    def test_filters_dbus_session_activations(self):
        stdout = (
            "  dbus-:1.2-org.example.App@1.service loaded active running ...\n"
            "  dbus-:1.16-org.a11y.atspi.Registry@0.service loaded active running ...\n"
            "  mako.service loaded active running Wayland notification daemon\n"
        )

        assert parse_running_services(stdout, Scope.USER) == [
            svc(Scope.USER, "mako.service")
        ]

    def test_sorts_alphabetically(self):
        stdout = (
            "  zfs.service loaded active running ...\n"
            "  atd.service loaded active running ...\n"
            "  mongo.service loaded active running ...\n"
        )

        names = [s.name for s in parse_running_services(stdout, Scope.SYSTEM)]

        assert names == ["atd.service", "mongo.service", "zfs.service"]

    def test_keeps_template_instances(self):
        stdout = "  user@1000.service loaded active running User Manager for UID 1000\n"

        assert parse_running_services(stdout, Scope.SYSTEM) == [
            svc(Scope.SYSTEM, "user@1000.service")
        ]

    def test_attaches_supplied_scope(self):
        stdout = "  mako.service loaded active running ...\n"

        result = parse_running_services(stdout, Scope.USER)

        assert result == [svc(Scope.USER, "mako.service")]

    def test_parses_real_system_fixture(self):
        stdout = (FIXTURES / "system-running.stdout.txt").read_text()

        services = parse_running_services(stdout, Scope.SYSTEM)

        assert all(s.scope == Scope.SYSTEM for s in services)
        assert all(s.name.endswith(".service") for s in services)
        assert services == sorted(services)
        assert svc(Scope.SYSTEM, "auditd.service") in services
        assert svc(Scope.SYSTEM, "user@1000.service") in services

    def test_parses_real_user_fixture(self):
        stdout = (FIXTURES / "user-running.stdout.txt").read_text()

        services = parse_running_services(stdout, Scope.USER)

        assert all(s.scope == Scope.USER for s in services)
        assert all(s.name.endswith(".service") for s in services)
        # dbus session activations are filtered
        assert not any(s.name.startswith("dbus-:") for s in services)
        # known long-lived user services survive
        assert svc(Scope.USER, "pipewire.service") in services
        assert svc(Scope.USER, "xremap.service") in services


class TestDiffServices:
    def test_no_drift_when_baseline_equals_current(self):
        baseline = [
            svc(Scope.SYSTEM, "auditd.service"),
            svc(Scope.USER, "mako.service"),
        ]
        current = list(reversed(baseline))

        drift = diff_services(baseline, current)

        assert drift == Drift(added=(), removed=())
        assert drift.has_drift is False

    def test_detects_added_service(self):
        baseline = [svc(Scope.SYSTEM, "auditd.service")]
        added = svc(Scope.USER, "ollama.service")
        current = baseline + [added]

        drift = diff_services(baseline, current)

        assert drift.added == (added,)
        assert drift.removed == ()
        assert drift.has_drift is True

    def test_detects_removed_service(self):
        removed = svc(Scope.USER, "ollama.service")
        baseline = [removed, svc(Scope.SYSTEM, "auditd.service")]
        current = [svc(Scope.SYSTEM, "auditd.service")]

        drift = diff_services(baseline, current)

        assert drift.added == ()
        assert drift.removed == (removed,)

    def test_treats_same_name_in_different_scopes_as_distinct(self):
        baseline = [svc(Scope.SYSTEM, "dbus-broker.service")]
        current = [
            svc(Scope.SYSTEM, "dbus-broker.service"),
            svc(Scope.USER, "dbus-broker.service"),
        ]

        drift = diff_services(baseline, current)

        assert drift.added == (svc(Scope.USER, "dbus-broker.service"),)
        assert drift.removed == ()
