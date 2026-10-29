"""Probe only fictional logins and static files on the loopback staging stack."""

import re
import secrets
from http.cookiejar import CookieJar
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import HTTPCookieProcessor, ProxyHandler, Request, build_opener


STAGING = "http://127.0.0.1:18002"
SOURCE = "http://127.0.0.1:18000"
CSRF = re.compile(rb'name="csrfmiddlewaretoken" value="([^"]+)"')


def fetch(opener, url: str, data: bytes | None = None):
    # Browsers send Origin for login POSTs. The original probe omitted it and
    # therefore missed a real CSRF failure when the gateway dropped the port.
    headers = {"Origin": STAGING, "Referer": url} if data is not None else {}
    request = Request(url, data=data, headers=headers)
    try:
        with opener.open(request, timeout=10) as response:
            return response.status, response.headers, response.read()
    except HTTPError as error:
        return error.code, error.headers, error.read()


def main() -> None:
    opener = build_opener(ProxyHandler({}), HTTPCookieProcessor(CookieJar()))
    code, _, login = fetch(opener, STAGING + "/login/")
    if code != 200 or b"csrfmiddlewaretoken" not in login:
        raise SystemExit("STAGING_LOGIN_NOT_READY")
    print("STAGING_LOGIN_HTTP_200")

    for asset, marker in (("/static/workbench/site.css", b".app-shell"),
                          ("/static/workbench/site.js", b"document")):
        code, headers, body = fetch(opener, STAGING + asset)
        if code != 200 or marker not in body:
            raise SystemExit("STAGING_STATIC_NOT_READY")
        expected_type = "text/css" if asset.endswith(".css") else "javascript"
        if expected_type not in headers.get("Content-Type", ""):
            raise SystemExit("STAGING_STATIC_CONTENT_TYPE_WRONG")
    print("STAGING_STATIC_CSS_JS_HTTP_200")

    code, _, admin = fetch(opener, STAGING + "/admin/login/")
    if code != 200:
        raise SystemExit("STAGING_ADMIN_LOGIN_NOT_READY")
    login_csrf = CSRF.search(login)
    admin_csrf = CSRF.search(admin)
    if not login_csrf or not admin_csrf:
        raise SystemExit("STAGING_CSRF_MISSING")
    username = "stage_probe_" + secrets.token_hex(8)
    for number in range(8):
        endpoint, token = (("/login/", login_csrf.group(1)) if number % 2 == 0
                           else ("/admin/login/", admin_csrf.group(1)))
        data = urlencode({"username": username, "password": "fictional-wrong-password",
                          "csrfmiddlewaretoken": token.decode("ascii")}).encode()
        code, _, _ = fetch(opener, STAGING + endpoint, data)
        if code != 200:
            raise SystemExit(f"STAGING_LOGIN_FAILURE_{number + 1}_STATUS_{code}")
    data = urlencode({"username": username, "password": "fictional-wrong-password",
                      "csrfmiddlewaretoken": admin_csrf.group(1).decode("ascii")}).encode()
    code, _, body = fetch(opener, STAGING + "/admin/login/", data)
    if code != 429 or "15 分钟后再试".encode() not in body:
        raise SystemExit("STAGING_SHARED_LOGIN_THROTTLE_FAILED")
    print("STAGING_SHARED_LOGIN_THROTTLE_HTTP_429")

    code, _, body = fetch(opener, SOURCE + "/login/")
    if code != 200 or not body:
        raise SystemExit("SOURCE_TEST_LOGIN_NOT_READY")
    print("SOURCE_TEST_LOGIN_HTTP_200_AFTER_STAGING_PROBE")


if __name__ == "__main__":
    main()
