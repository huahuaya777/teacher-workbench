"""Check only DNS, TCP and TLS for the member's configured Qwen host.

No API key is decrypted and no HTTP request or teaching text is sent.
"""

import os
import socket
import ssl
from urllib.parse import urlparse

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.contrib.auth import get_user_model

from workbench.models import ModelCredential


user = get_user_model().objects.get(username="huahua")
credential = ModelCredential.objects.get(owner=user)
parsed = urlparse(credential.api_base_url)
assert parsed.scheme == "https" and parsed.hostname and parsed.port in (None, 443)
host = parsed.hostname
try:
    addresses = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    assert addresses
    print("PILOT_QWEN_DNS_OK", flush=True)
    with socket.create_connection((host, 443), timeout=8) as connection:
        print("PILOT_QWEN_TCP_443_OK", flush=True)
        with ssl.create_default_context().wrap_socket(connection, server_hostname=host) as secure:
            assert secure.version() in ("TLSv1.2", "TLSv1.3")
            print("PILOT_QWEN_TLS_CERT_OK", flush=True)
except (OSError, ssl.SSLError) as exc:
    print("PILOT_QWEN_CONNECTIVITY_FAILED=" + type(exc).__name__, flush=True)
    raise SystemExit(1)
