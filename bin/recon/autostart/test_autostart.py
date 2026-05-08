import pytest

from autostart import UnitName


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
