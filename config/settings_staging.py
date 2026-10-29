"""Disposable HTTP staging settings; never use as the production settings module."""

import os

if os.getenv("TW_STAGING") != "1" or os.getenv("DJANGO_DEBUG") != "1":
    raise RuntimeError("Staging requires TW_STAGING=1 and DJANGO_DEBUG=1")

from .settings import *  # noqa: F403,E402

# The SSH loopback tunnel uses plain HTTP, so the base settings retain
# non-Secure cookies and the manual staging queue. Hide technical error pages
# even in this disposable environment; otherwise a 404 reveals URL patterns
# and a 500 can reveal application details.
DEBUG = False

# The shared Redis cache still exercises the same login throttle as production.
CACHES = {"default": {
    "BACKEND": "django.core.cache.backends.redis.RedisCache",
    "LOCATION": os.environ["REDIS_URL"],
}}
