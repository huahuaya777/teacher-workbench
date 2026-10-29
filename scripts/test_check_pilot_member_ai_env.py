"""Member AI runtime must keep the pilot isolation and secret boundaries."""

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parent))
from check_pilot_member_ai_env import validate
from test_check_pilot_env import safe_values


class MemberAIPilotGateTests(unittest.TestCase):
    def test_only_explicit_member_mode_passes(self):
        values = safe_values()
        values.update(AI_ENABLED="1", AI_MEMBER_TASKS_ENABLED="1")
        self.assertEqual(validate(values), [])
        for name, bad in (("AI_ENABLED", "0"), ("AI_MEMBER_TASKS_ENABLED", "0"),
                          ("AI_API_KEY", "fictional-secret"), ("AI_LOCAL_QUEUE", "1"),
                          ("DJANGO_CSRF_TRUSTED_ORIGINS", "http://10.0.30.5:18443")):
            with self.subTest(name=name):
                invalid = dict(values)
                invalid[name] = bad
                self.assertTrue(validate(invalid))


if __name__ == "__main__":
    unittest.main()
