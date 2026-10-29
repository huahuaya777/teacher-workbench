"""Read only the output token limits inside the running worker."""

import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

from django.conf import settings

assert settings.AI_MAX_OUTPUT_TOKENS == 1500
assert settings.AI_MEMBER_MAX_OUTPUT_TOKENS == 6000
print("PILOT_AI_MAX_OUTPUT_TOKENS=1500")
print("PILOT_AI_MEMBER_MAX_OUTPUT_TOKENS=6000")
