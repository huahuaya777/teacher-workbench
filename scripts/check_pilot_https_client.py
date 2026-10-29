"""Verify pilot TLS, CSRF, and login handling without a real account.

Use only the copied public pilot CA. This never prints cookies or page bodies.
"""

from __future__ import annotations

import argparse
from html.parser import HTMLParser
from http.cookiejar import CookieJar
from pathlib import Path
import ssl
from urllib.parse import urlencode
from urllib.request import HTTPSHandler, HTTPCookieProcessor, ProxyHandler, Request, build_opener


ORIGIN = "https://10.0.30.5:18443"


class CsrfParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.token: str | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "input":
            return
        values = dict(attrs)
        if values.get("name") == "csrfmiddlewaretoken":
            self.token = values.get("value")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ca", required=True, type=Path)
    args = parser.parse_args()
    context = ssl.create_default_context(cafile=str(args.ca))
    opener = build_opener(ProxyHandler({}), HTTPSHandler(context=context), HTTPCookieProcessor(CookieJar()))
    with opener.open(ORIGIN + "/login/", timeout=15) as response:
        assert response.status == 200
        cookie = response.headers.get("Set-Cookie", "")
        assert "Secure" in cookie and "HttpOnly" in cookie
        body = response.read(200_000).decode("utf-8")
    parsed = CsrfParser()
    parsed.feed(body)
    assert parsed.token
    print("PILOT_WINDOWS_STRICT_TLS_AND_LOGIN_GET_200")

    payload = urlencode({
        "username": "pilot_invalid_login_probe_20261024",
        "password": "fictional-invalid-password",
        "csrfmiddlewaretoken": parsed.token,
    }).encode("ascii")
    request = Request(
        ORIGIN + "/login/",
        data=payload,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Origin": ORIGIN,
            "Referer": ORIGIN + "/login/",
        },
        method="POST",
    )
    with opener.open(request, timeout=15) as response:
        assert response.status == 200
        assert response.geturl() == ORIGIN + "/login/"
        body = response.read(200_000).decode("utf-8")
    assert "用户名或密码不正确" in body or "登录失败" in body
    print("PILOT_WINDOWS_HTTPS_CSRF_POST_HANDLED_NO_REAL_ACCOUNT")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
