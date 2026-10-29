"""Read only the non-secret output token limit inside the running worker."""

import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

from django.conf import settings

value = settings.AI_MAX_OUTPUT_TOKENS
assert isinstance(value, int) and 200 <= value <= 2000
print(f"PILOT_AI_MAX_OUTPUT_TOKENS={value}")
member_value = settings.AI_MEMBER_MAX_OUTPUT_TOKENS
assert isinstance(member_value, int) and 200 <= member_value <= 4000
print(f"PILOT_AI_MEMBER_MAX_OUTPUT_TOKENS={member_value}")
