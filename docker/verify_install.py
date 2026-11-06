"""Fictional-data smoke check; only run on explicitly disposable container volumes."""
import http.cookiejar
from io import BytesIO
import json
import os
import re
import secrets
import sys
import urllib.parse
import urllib.request

from .runtime import DATA, KEYRING


def main():
    if os.getenv("TW_CONTAINER_SMOKE") != "1":
        raise SystemExit("Refusing: set TW_CONTAINER_SMOKE=1 only on disposable test volumes")
    import django
    django.setup()
    from django.conf import settings
    from django.contrib.auth import get_user_model
    from django.core.files.uploadedfile import SimpleUploadedFile
    from django.core.management import call_command
    from django.test import Client
    from docx import Document
    from workbench.credential_vault import seal_key, unseal_key_for_owner
    from workbench.models import Material, ModelCredential, Worksheet, WorksheetVersion
    assert not settings.AI_ENABLED
    state = DATA / "fictional-smoke.json"
    if sys.argv[1] == "seed":
        assert not get_user_model().objects.exists(), "Requires an empty disposable installation"
        password = secrets.token_urlsafe(24)
        os.environ["DJANGO_SUPERUSER_PASSWORD"] = password
        call_command("createsuperuser", username="fictional_portable_admin", email="", interactive=False)
        del os.environ["DJANGO_SUPERUSER_PASSWORD"]
        owner = get_user_model().objects.get(username="fictional_portable_admin")
        get_user_model().objects.create_user("fictional_portable_other")
        document = Document()
        document.add_paragraph("虚构安装验收资料（非真实教学资料）：计算 1+1。")
        output = BytesIO()
        document.save(output)
        client = Client(HTTP_HOST="localhost")
        client.force_login(owner)
        response = client.post("/materials/upload/", {"file": SimpleUploadedFile("fictional.docx", output.getvalue())})
        assert response.status_code == 302
        material = Material.objects.get(owner=owner)
        worksheet = Worksheet.objects.create(owner=owner, material=material, title="虚构安装验收")
        WorksheetVersion.objects.create(worksheet=worksheet, number=1, content={
            "title": "虚构安装验收", "questions": [
                {"stem": "计算 [[math:1+1]]", "answer": "2", "source": "非 AI 生成的虚构测试"},
            ],
        })
        assert client.post(f"/worksheets/{worksheet.pk}/v1/mark-final/").status_code == 302
        credential = ModelCredential(owner=owner, label="虚构安装验收", provider="qwen",
                                     api_base_url="https://dashscope.aliyuncs.com/compatible-mode/v1", model_name="qwen-flash")
        seal_key(credential, "sk-fictional-container-smoke-only")
        credential.save()
        state.write_text(json.dumps({"password": password}))
    owner = get_user_model().objects.get(username="fictional_portable_admin")
    material = Material.objects.get(owner=owner)
    worksheet = Worksheet.objects.get(owner=owner)
    assert worksheet.final_version.number == 1
    assert material.file.open("rb").read()
    credential = ModelCredential.objects.get(owner=owner)
    assert unseal_key_for_owner(credential, owner.pk) == "sk-fictional-container-smoke-only"
    client = Client(HTTP_HOST="localhost")
    client.force_login(owner)
    for variant in ("student", "teacher"):
        exported = client.get(f"/worksheets/{worksheet.pk}/v1/{variant}.docx")
        assert exported.status_code == 200
        assert Document(BytesIO(b"".join(exported.streaming_content))).paragraphs
        exported.close()
    client.force_login(get_user_model().objects.get(username="fictional_portable_other"))
    assert client.get(f"/materials/{material.pk}/download/").status_code == 404
    assert client.get(f"/worksheets/{worksheet.pk}/").status_code == 404
    assert client.post(f"/worksheets/{worksheet.pk}/v1/mark-final/").status_code == 404
    # Real HTTP cookie/CSRF login against the running Gunicorn process.
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    url = "http://127.0.0.1:8000/login/"
    html = opener.open(url, timeout=5).read().decode()
    token = re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"', html).group(1)
    body = urllib.parse.urlencode({"csrfmiddlewaretoken": token, "username": owner.username,
                                  "password": json.loads(state.read_text())["password"]}).encode()
    result = opener.open(urllib.request.Request(url, data=body, headers={"Origin": "http://127.0.0.1:8000"}), timeout=10)
    assert "fictional_portable_admin" in result.read().decode()
    assert opener.open("http://127.0.0.1:8000/static/workbench/site.css", timeout=5).status == 200
    assert all(path.stat().st_mode & 0o777 == 0o600 for path in KEYRING.iterdir())
    print("PORTABLE_INSTALL_CONTENT_LOGIN_EXPORT_KEYS_AND_ISOLATION_OK")


if __name__ == "__main__":
    main()
