"""Store member API keys with authenticated encryption; never initiate a request."""

import base64
import binascii
import json
import os
from pathlib import Path
import re
import stat
from urllib.parse import urlsplit

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from django.conf import settings
from django.contrib.auth import get_user_model


class VaultUnavailable(Exception):
    pass


class VaultIntegrityError(Exception):
    pass


class CredentialInvalid(ValueError):
    pass


_WORKSPACE_HOST = re.compile(r"ws-[a-z0-9]+\.cn-beijing\.maas\.aliyuncs\.com\Z")
_MODEL = "qwen-flash"


def normalize_qwen_config(base_url, model_name):
    """Accept only the Beijing OpenAI-compatible endpoint tested for this slice."""
    if not isinstance(base_url, str) or base_url != base_url.strip() or not base_url.isascii():
        raise CredentialInvalid("请填写百炼北京地域的 OpenAI 兼容地址。")
    try:
        parsed = urlsplit(base_url)
        host, port = parsed.hostname, parsed.port
    except ValueError as exc:
        raise CredentialInvalid("接口地址格式不正确。") from exc
    if (parsed.scheme != "https" or not host or port not in (None, 443)
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or parsed.path.rstrip("/") != "/compatible-mode/v1"
            or (host != "dashscope.aliyuncs.com" and not _WORKSPACE_HOST.fullmatch(host))):
        raise CredentialInvalid("目前仅保存百炼北京地域的 OpenAI 兼容地址。")
    if model_name != _MODEL:
        raise CredentialInvalid("目前仅支持已验证的 qwen-flash 配置。")
    return f"https://{host}/compatible-mode/v1"


def _load_key(version):
    directory_name = settings.MODEL_KEYRING_DIR
    if not directory_name or not isinstance(version, int) or not 1 <= version <= 9999:
        raise VaultUnavailable("模型密钥保管尚未配置。")
    directory = Path(directory_name)
    if not directory.is_absolute():
        raise VaultUnavailable("模型密钥保管尚未配置。")
    try:
        if directory.is_symlink():
            raise VaultUnavailable("模型密钥保管目录不能是链接。")
        resolved_dir = directory.resolve(strict=True)
        if resolved_dir.is_relative_to(Path(settings.BASE_DIR).resolve()):
            raise VaultUnavailable("模型密钥保管目录不能放在项目代码内。")
        directory_info = resolved_dir.stat()
        if os.name == "posix" and (
            not stat.S_ISDIR(directory_info.st_mode)
            or stat.S_IMODE(directory_info.st_mode) != 0o700
            or (os.geteuid() != 0 and directory_info.st_uid != os.geteuid())
        ):
            raise VaultUnavailable("模型密钥保管目录权限不正确。")
        key_path = resolved_dir / f"v{version}.key"
        if key_path.is_symlink():
            raise VaultUnavailable("模型密钥文件不能是链接。")
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
        fd = os.open(key_path, flags)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode):
                raise VaultUnavailable("模型密钥文件格式不正确。")
            if os.name == "posix" and (stat.S_IMODE(info.st_mode) != 0o600 or
                                       (os.geteuid() != 0 and info.st_uid != os.geteuid())):
                raise VaultUnavailable("模型密钥文件权限不正确。")
            with os.fdopen(fd, "rb", closefd=False) as source:
                encoded = source.read(129)
        finally:
            os.close(fd)
        key = base64.b64decode(encoded.strip(), validate=True)
        if len(key) != 32:
            raise ValueError("wrong key length")
        return key
    except (OSError, ValueError, binascii.Error) as exc:
        raise VaultUnavailable("模型密钥保管不可用。") from exc


def vault_ready():
    try:
        _load_key(settings.MODEL_ACTIVE_KEY_VERSION)
    except VaultUnavailable:
        return False
    return True


def _aad(credential):
    fields = ["teacher-workbench-model-key-v1", str(credential.owner_id), str(credential.pk),
              credential.provider, credential.api_base_url, credential.model_name]
    return json.dumps(fields, ensure_ascii=True, separators=(",", ":")).encode("ascii")


def seal_key(credential, plaintext):
    """Populate encrypted fields without saving, so callers control transactions."""
    if (not isinstance(plaintext, str) or not 8 <= len(plaintext) <= 512
            or not plaintext.isascii() or any(char.isspace() or not char.isprintable() for char in plaintext)):
        raise CredentialInvalid("API Key 应为 8～512 位不含空白的可打印字符。")
    if os.getenv("TW_STAGING") == "1" and not plaintext.startswith("sk-fictional-"):
        raise CredentialInvalid("隔离预发布仅允许虚构测试 Key。")
    if credential.provider != "qwen":
        raise CredentialInvalid("暂不支持该厂商。")
    credential.api_base_url = normalize_qwen_config(credential.api_base_url, credential.model_name)
    if not credential.owner_id or not credential.pk:
        raise CredentialInvalid("模型配置缺少所属成员或配置编号。")
    version = settings.MODEL_ACTIVE_KEY_VERSION
    key = _load_key(version)
    nonce = os.urandom(12)
    credential.key_ciphertext = AESGCM(key).encrypt(nonce, plaintext.encode("ascii"), _aad(credential))
    credential.key_nonce = nonce
    credential.key_version = version


def _unseal(credential):
    key = _load_key(credential.key_version)
    try:
        plaintext = AESGCM(key).decrypt(bytes(credential.key_nonce),
                                        bytes(credential.key_ciphertext), _aad(credential))
        return plaintext.decode("ascii")
    except (InvalidTag, ValueError, UnicodeError) as exc:
        raise VaultIntegrityError("模型配置解密失败。") from exc


def unseal_key_for_owner(credential, owner_id):
    """Only server-side code may call this; views must never render its result."""
    if (credential.owner_id != owner_id or
            not get_user_model().objects.filter(pk=owner_id, is_active=True).exists()):
        raise VaultIntegrityError("该模型配置不可用。")
    return _unseal(credential)


def reseal_with_active_key(credential):
    if credential.key_version == settings.MODEL_ACTIVE_KEY_VERSION:
        return False
    plaintext = _unseal(credential)
    seal_key(credential, plaintext)
    return True
