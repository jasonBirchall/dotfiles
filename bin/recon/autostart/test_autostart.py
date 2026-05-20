from pathlib import Path

import pytest

from _common import Drift, diff
from autostart.autostart import UnitName, parse_unit_files


def diff_units(baseline: list[UnitName], current: list[UnitName]) -> Drift[UnitName]:
    return diff(baseline, current)

FIXTURES = Path(__file__).parent / "fixtures"


class TestUnitName:
    def test_accepts_valid_service_name(self):
        name = "sshd.service"

        unit = UnitName(name)
        assert unit.value == name

    def test_rejects_empty_suffix(self):
        name = "sshd"

        with pytest.raises(ValueError):
            UnitName(name)

    def test_rejects_empty_string(self):
        name = ""

        with pytest.raises(ValueError):
            UnitName(name)

    def test_rejects_non_service_string(self):
        name = "test.notservice"

        with pytest.raises(ValueError):
            UnitName(name)

    def test_rejects_whitespace(self):
        name = " "

        with pytest.raises(ValueError):
            UnitName(name)

    def test_rejects_three_dots(self):
        name = "test.notservice.nope"

        with pytest.raises(ValueError):
            UnitName(name)

    def test_rejects_whitespace_and_dot(self):
        name = "test. notservice"

        with pytest.raises(ValueError):
            UnitName(name)


class TestParseUnitFiles:
    def test_returns_empty_list_for_empty_input(self):
        assert parse_unit_files("") == []

    def test_ignores_blank_lines(self):
        stdout = "\n  \nsshd.service enabled enabled\n\n"

        assert parse_unit_files(stdout) == [UnitName("sshd.service")]

    def test_drops_non_service_unit_types(self):
        stdout = (
            "cups.path                 enabled enabled\n"
            "sshd.service              enabled enabled\n"
            "graphical.target          enabled enabled\n"
            "sssd-kcm.socket           enabled enabled\n"
        )

        assert parse_unit_files(stdout) == [UnitName("sshd.service")]

    def test_sorts_unit_names_alphabetically(self):
        stdout = (
            "zfs.service enabled enabled\n"
            "atd.service enabled enabled\n"
            "mongo.service enabled enabled\n"
        )

        names = [u.value for u in parse_unit_files(stdout)]

        assert names == ["atd.service", "mongo.service", "zfs.service"]

    def test_accepts_template_service_names(self):
        stdout = "getty@.service enabled enabled\n"

        assert parse_unit_files(stdout) == [UnitName("getty@.service")]

    def test_parses_real_systemctl_fixture(self):
        stdout = (FIXTURES / "system-units.stdout.txt").read_text()

        units = parse_unit_files(stdout)

        names = [u.value for u in units]
        assert all(n.endswith(".service") for n in names)
        assert names == sorted(names)
        # Spot-check a couple of services from the fixture
        assert UnitName("sshd.service") not in units  # not in fixture
        assert UnitName("auditd.service") in units
        assert UnitName("getty@.service") in units


class TestDiffUnits:
    def test_no_drift_when_baseline_equals_current(self):
        baseline = [UnitName("a.service"), UnitName("b.service")]
        current = [UnitName("b.service"), UnitName("a.service")]

        drift = diff_units(baseline, current)

        assert drift == Drift(added=(), removed=())
        assert drift.has_drift is False

    def test_detects_added_units(self):
        baseline = [UnitName("a.service")]
        current = [UnitName("a.service"), UnitName("b.service")]

        drift = diff_units(baseline, current)

        assert drift.added == (UnitName("b.service"),)
        assert drift.removed == ()
        assert drift.has_drift is True

    def test_detects_removed_units(self):
        baseline = [UnitName("a.service"), UnitName("b.service")]
        current = [UnitName("a.service")]

        drift = diff_units(baseline, current)

        assert drift.added == ()
        assert drift.removed == (UnitName("b.service"),)
        assert drift.has_drift is True

    def test_detects_added_and_removed_sorted(self):
        baseline = [UnitName("b.service"), UnitName("c.service")]
        current = [UnitName("a.service"), UnitName("b.service"), UnitName("d.service")]

        drift = diff_units(baseline, current)

        assert drift.added == (UnitName("a.service"), UnitName("d.service"))
        assert drift.removed == (UnitName("c.service"),)
