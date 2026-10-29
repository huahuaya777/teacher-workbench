"""Encrypt or recover a staging master key using an interactive passphrase.

Run inside the already-built staging image, with no network and only the
required input/output directories mounted. Never pass a passphrase in argv,
environment variables, a shell pipe, or a project file.
"""

from __future__ import annotations

import base64
import binascii
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import stat
import sys


FORMAT = "teacher-workbench-offline-model-key-v1"
KDF = {"name": "scrypt", "n": 2**17, "r": 8, "p": 1, "length": 32}
HEADER_NAMES = {"format", "key_version", "kdf", "salt", "nonce", "fingerprint"}
PACKAGE_NAMES = HEADER_NAMES | {"ciphertext"}
AAD_CONTEXT = b"teacher-workbench:staging-model-key:offline-package:v1\x00"


def encoded(value: bytes) -> str:
    return base64.b64encode(value).decode("ascii")


def decoded(value: str, size: int) -> bytes:
    if not isinstance(value, str):
        raise ValueError("PACKAGE_BASE64_INVALID")
    try:
        raw = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise ValueError("PACKAGE_BASE64_INVALID") from exc
    if len(raw) != size or encoded(raw) != value:
        raise ValueError("PACKAGE_BASE64_SIZE_INVALID")
    return raw


def canonical_header(header: dict[str, object]) -> bytes:
    return AAD_CONTEXT + json.dumps(header, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def derived_key(password: str, salt: bytes) -> bytes:
    if not isinstance(password, str) or not password:
        raise ValueError("PASSPHRASE_EMPTY")
    return Scrypt(salt=salt, length=KDF["length"], n=KDF["n"], r=KDF["r"], p=KDF["p"]).derive(
        password.encode("utf-8")
    )


def seal(raw_key: bytes, password: str) -> bytes:
    if len(raw_key) != 32:
        raise ValueError("MASTER_KEY_SIZE_INVALID")
    if len(password) < 20:
        raise ValueError("PASSPHRASE_TOO_SHORT")
    salt, nonce = secrets.token_bytes(16), secrets.token_bytes(12)
    header: dict[str, object] = {
        "format": FORMAT,
        "key_version": 1,
        "kdf": KDF,
        "salt": encoded(salt),
        "nonce": encoded(nonce),
        "fingerprint": hashlib.sha256(raw_key).hexdigest(),
    }
    ciphertext = AESGCM(derived_key(password, salt)).encrypt(nonce, raw_key, canonical_header(header))
    package = header | {"ciphertext": encoded(ciphertext)}
    return (json.dumps(package, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("ascii")


def unseal(blob: bytes, password: str) -> bytes:
    if len(blob) > 4096 or not blob.endswith(b"\n"):
        raise ValueError("PACKAGE_FORMAT_INVALID")
    try:
        package = json.loads(blob.decode("ascii"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError("PACKAGE_FORMAT_INVALID") from exc
    if not isinstance(package, dict) or set(package) != PACKAGE_NAMES:
        raise ValueError("PACKAGE_FIELDS_INVALID")
    if (json.dumps(package, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("ascii") != blob:
        raise ValueError("PACKAGE_CANONICAL_FORMAT_INVALID")
    if package["format"] != FORMAT or type(package["key_version"]) is not int or package["key_version"] != 1:
        raise ValueError("PACKAGE_VERSION_INVALID")
    if package["kdf"] != KDF:
        raise ValueError("PACKAGE_KDF_INVALID")
    fingerprint = package["fingerprint"]
    if not isinstance(fingerprint, str) or not re.fullmatch(r"[0-9a-f]{64}", fingerprint):
        raise ValueError("PACKAGE_FINGERPRINT_INVALID")
    salt = decoded(package["salt"], 16)
    nonce = decoded(package["nonce"], 12)
    ciphertext = decoded(package["ciphertext"], 48)
    header = {name: package[name] for name in HEADER_NAMES}
    try:
        raw_key = AESGCM(derived_key(password, salt)).decrypt(nonce, ciphertext, canonical_header(header))
    except InvalidTag as exc:
        raise ValueError("PASSPHRASE_OR_PACKAGE_INVALID") from exc
    if len(raw_key) != 32 or hashlib.sha256(raw_key).hexdigest() != fingerprint:
        raise ValueError("MASTER_KEY_FINGERPRINT_INVALID")
    return raw_key


def require_dir(path: Path) -> None:
    meta = path.lstat()
    if not stat.S_ISDIR(meta.st_mode) or meta.st_uid != os.geteuid() or stat.S_IMODE(meta.st_mode) != 0o700:
        raise ValueError("KEY_PACKAGE_DIRECTORY_UNSAFE")


def require_file(path: Path, maximum: int) -> bytes:
    meta = path.lstat()
    if not stat.S_ISREG(meta.st_mode) or meta.st_uid != os.geteuid() or stat.S_IMODE(meta.st_mode) != 0o600:
        raise ValueError("KEY_PACKAGE_FILE_UNSAFE")
    if meta.st_size < 1 or meta.st_size > maximum:
        raise ValueError("KEY_PACKAGE_FILE_SIZE_INVALID")
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as stream:
        opened = os.fstat(stream.fileno())
        if (opened.st_ino != meta.st_ino or opened.st_dev != meta.st_dev or opened.st_size != meta.st_size
                or opened.st_uid != meta.st_uid or stat.S_IMODE(opened.st_mode) != 0o600):
            raise ValueError("KEY_PACKAGE_FILE_CHANGED")
        blob = stream.read(maximum + 1)
    if len(blob) != meta.st_size:
        raise ValueError("KEY_PACKAGE_FILE_CHANGED")
    return blob


def write_new(path: Path, content: bytes) -> None:
    require_dir(path.parent)
    handle = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(handle, "wb") as stream:
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())
    if stat.S_IMODE(path.stat().st_mode) != 0o600:
        raise ValueError("KEY_PACKAGE_OUTPUT_MODE_UNSAFE")


def prompt_passphrase(confirm: bool) -> str:
    if not sys.stdin.isatty() or not sys.stderr.isatty():
        raise ValueError("INTERACTIVE_TTY_REQUIRED")
    first = getpass.getpass("恢复包解锁口令（输入不显示）：")
    if confirm:
        second = getpass.getpass("再次输入解锁口令：")
        if first != second:
            raise ValueError("PASSPHRASES_DO_NOT_MATCH")
        if len(first) < 20:
            raise ValueError("PASSPHRASE_TOO_SHORT")
    return first


def main() -> int:
    if os.name != "posix" or len(sys.argv) not in {3, 4}:
        print("KEY_PACKAGE_WRONG_PLATFORM_OR_ARGS")
        return 2
    mode = sys.argv[1]
    if (mode == "export" and len(sys.argv) != 4) or (mode == "restore" and len(sys.argv) != 4) or (
        mode == "verify" and len(sys.argv) != 3
    ) or mode not in {"export", "restore", "verify"}:
        print("KEY_PACKAGE_WRONG_MODE_OR_ARGS")
        return 2
    source = Path(sys.argv[2])
    if source.is_symlink() or not source.is_absolute():
        print("KEY_PACKAGE_SOURCE_PATH_UNSAFE")
        return 2
    destination = Path(sys.argv[3]) if len(sys.argv) == 4 else None
    if destination is not None and (not destination.is_absolute() or destination.is_symlink()):
        print("KEY_PACKAGE_TARGET_PATH_UNSAFE")
        return 2
    os.umask(0o077)
    try:
        require_dir(source.parent)
        if mode == "export":
            if source.name != "v1.key" or destination is None or not destination.name.endswith(".json"):
                raise ValueError("KEY_PACKAGE_PATHS_UNEXPECTED")
            raw_text = require_file(source, 128)
            raw_key = decoded(raw_text.decode("ascii").removesuffix("\n"), 32)
            password = prompt_passphrase(confirm=True)
            blob = seal(raw_key, password)
            if unseal(blob, password) != raw_key:
                raise ValueError("KEY_PACKAGE_SELF_CHECK_FAILED")
            write_new(destination, blob)
            print("OFFLINE_KEY_PACKAGE_CREATED_ENCRYPTED_ONLY", flush=True)
            print(f"OFFLINE_KEY_PACKAGE_SHA256={hashlib.sha256(blob).hexdigest()}", flush=True)
        else:
            blob = require_file(source, 4096)
            password = prompt_passphrase(confirm=False)
            raw_key = unseal(blob, password)
            if mode == "restore":
                if destination is None or destination.name != "v1.key":
                    raise ValueError("KEY_PACKAGE_TARGET_UNEXPECTED")
                write_new(destination, encoded(raw_key).encode("ascii") + b"\n")
                print("OFFLINE_KEY_RESTORED_TO_NEW_DIRECTORY", flush=True)
            else:
                print("OFFLINE_KEY_PACKAGE_DECRYPTION_VERIFIED", flush=True)
        return 0
    except (OSError, UnicodeError, ValueError) as exc:
        print(str(exc), flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
