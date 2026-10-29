"""Encrypt or recover the fixed pilot escrow without network or secret output."""

from __future__ import annotations

import base64
import binascii
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import stat
import sys

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt


FORMAT = "teacher-workbench-pilot-escrow-Lx7aqLEz-v1"
AAD = b"teacher-workbench:pilot-escrow:Lx7aqLEz:v1\x00"
KDF = {"name": "scrypt", "n": 2**17, "r": 8, "p": 1, "length": 32}
SECRET_NAMES = ("env.pilot", "v1.key", "caddy_data.tar.gz", "caddy_config.tar.gz")
ALL_NAMES = SECRET_NAMES + ("SHA256SUMS", "STATE")
MAX_BYTES = {
    "env.pilot": 16 * 1024,
    "v1.key": 128,
    "caddy_data.tar.gz": 1024 * 1024,
    "caddy_config.tar.gz": 1024 * 1024,
    "SHA256SUMS": 1024,
    "STATE": 64,
}
MAX_PACKAGE_BYTES = 3 * 1024 * 1024
PACKAGE_NAME = "teacher-workbench-pilot-escrow-Lx7aqLEz.json"


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("ascii")


def encoded(value: bytes) -> str:
    return base64.b64encode(value).decode("ascii")


def decoded(value: object, maximum: int) -> bytes:
    if not isinstance(value, str):
        raise ValueError("PACKAGE_BASE64_INVALID")
    try:
        raw = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise ValueError("PACKAGE_BASE64_INVALID") from exc
    if not raw or len(raw) > maximum or encoded(raw) != value:
        raise ValueError("PACKAGE_BASE64_SIZE_INVALID")
    return raw


def validate_files(files: dict[str, bytes]) -> None:
    if set(files) != set(ALL_NAMES):
        raise ValueError("ESCROW_FILE_SET_INVALID")
    for name in ALL_NAMES:
        if not files[name] or len(files[name]) > MAX_BYTES[name]:
            raise ValueError("ESCROW_FILE_SIZE_INVALID")
    if files["STATE"] != b"PILOT_ESCROW_COMPLETE\n":
        raise ValueError("ESCROW_STATE_INVALID")
    try:
        lines = files["SHA256SUMS"].decode("ascii").splitlines()
    except UnicodeError as exc:
        raise ValueError("ESCROW_MANIFEST_INVALID") from exc
    hashes: dict[str, str] = {}
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        if match is None or match[2] in hashes:
            raise ValueError("ESCROW_MANIFEST_INVALID")
        hashes[match[2]] = match[1]
    if set(hashes) != set(SECRET_NAMES):
        raise ValueError("ESCROW_MANIFEST_FILE_SET_INVALID")
    for name in SECRET_NAMES:
        if hashlib.sha256(files[name]).hexdigest() != hashes[name]:
            raise ValueError("ESCROW_MANIFEST_HASH_INVALID")


def derive(password: str, salt: bytes) -> bytes:
    if not password:
        raise ValueError("PASSPHRASE_EMPTY")
    return Scrypt(salt=salt, length=32, n=KDF["n"], r=KDF["r"], p=KDF["p"]).derive(password.encode("utf-8"))


def seal(files: dict[str, bytes], password: str) -> bytes:
    validate_files(files)
    if len(password) < 20:
        raise ValueError("PASSPHRASE_TOO_SHORT")
    salt, nonce = secrets.token_bytes(16), secrets.token_bytes(12)
    header: dict[str, object] = {"format": FORMAT, "kdf": KDF, "salt": encoded(salt), "nonce": encoded(nonce)}
    plaintext = canonical({"files": {name: encoded(files[name]) for name in ALL_NAMES}})
    ciphertext = AESGCM(derive(password, salt)).encrypt(nonce, plaintext, AAD + canonical(header))
    result = canonical(header | {"ciphertext": encoded(ciphertext)})
    if len(result) > MAX_PACKAGE_BYTES:
        raise ValueError("PACKAGE_TOO_LARGE")
    return result


def unseal(blob: bytes, password: str) -> dict[str, bytes]:
    if not blob or len(blob) > MAX_PACKAGE_BYTES or not blob.endswith(b"\n"):
        raise ValueError("PACKAGE_FORMAT_INVALID")
    try:
        package = json.loads(blob.decode("ascii"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError("PACKAGE_FORMAT_INVALID") from exc
    if not isinstance(package, dict) or set(package) != {"format", "kdf", "salt", "nonce", "ciphertext"}:
        raise ValueError("PACKAGE_FIELDS_INVALID")
    if canonical(package) != blob or package["format"] != FORMAT or package["kdf"] != KDF:
        raise ValueError("PACKAGE_VERSION_INVALID")
    salt = decoded(package["salt"], 16)
    nonce = decoded(package["nonce"], 12)
    if len(salt) != 16 or len(nonce) != 12:
        raise ValueError("PACKAGE_RANDOM_FIELDS_INVALID")
    ciphertext = decoded(package["ciphertext"], MAX_PACKAGE_BYTES)
    header = {name: package[name] for name in ("format", "kdf", "salt", "nonce")}
    try:
        plaintext = AESGCM(derive(password, salt)).decrypt(nonce, ciphertext, AAD + canonical(header))
    except InvalidTag as exc:
        raise ValueError("PASSPHRASE_OR_PACKAGE_INVALID") from exc
    try:
        decoded_plaintext = json.loads(plaintext.decode("ascii"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError("PACKAGE_CONTENT_INVALID") from exc
    if not isinstance(decoded_plaintext, dict) or set(decoded_plaintext) != {"files"} or canonical(decoded_plaintext) != plaintext:
        raise ValueError("PACKAGE_CONTENT_INVALID")
    file_data = decoded_plaintext["files"]
    if not isinstance(file_data, dict) or set(file_data) != set(ALL_NAMES):
        raise ValueError("PACKAGE_FILE_SET_INVALID")
    files = {name: decoded(file_data[name], MAX_BYTES[name]) for name in ALL_NAMES}
    validate_files(files)
    return files


def require_dir(path: Path, *, empty: bool = False) -> None:
    meta = path.lstat()
    if not stat.S_ISDIR(meta.st_mode) or meta.st_uid != os.geteuid() or stat.S_IMODE(meta.st_mode) != 0o700:
        raise ValueError("DIRECTORY_OWNER_OR_MODE_UNSAFE")
    if empty and any(path.iterdir()):
        raise ValueError("OUTPUT_DIRECTORY_NOT_EMPTY")


def read_file(path: Path, maximum: int) -> bytes:
    meta = path.lstat()
    if not stat.S_ISREG(meta.st_mode) or meta.st_uid != os.geteuid() or stat.S_IMODE(meta.st_mode) != 0o600:
        raise ValueError("INPUT_FILE_OWNER_OR_MODE_UNSAFE")
    if meta.st_size < 1 or meta.st_size > maximum:
        raise ValueError("INPUT_FILE_SIZE_UNSAFE")
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as stream:
        opened = os.fstat(stream.fileno())
        if (opened.st_ino != meta.st_ino or opened.st_dev != meta.st_dev or opened.st_size != meta.st_size
                or opened.st_uid != meta.st_uid or stat.S_IMODE(opened.st_mode) != 0o600):
            raise ValueError("INPUT_FILE_CHANGED")
        content = stream.read(maximum + 1)
    if len(content) != meta.st_size:
        raise ValueError("INPUT_FILE_CHANGED")
    return content


def write_new(path: Path, content: bytes) -> None:
    require_dir(path.parent)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as output:
        output.write(content)
        output.flush()
        os.fsync(output.fileno())


def prompt(confirm: bool) -> str:
    if not sys.stdin.isatty() or not sys.stderr.isatty():
        raise ValueError("INTERACTIVE_TTY_REQUIRED")
    first = getpass.getpass("试点恢复包解锁口令（输入不显示）：")
    if confirm:
        second = getpass.getpass("再次输入解锁口令：")
        if first != second:
            raise ValueError("PASSPHRASES_DO_NOT_MATCH")
        if len(first) < 20:
            raise ValueError("PASSPHRASE_TOO_SHORT")
    return first


def main() -> int:
    if os.name != "posix" or len(sys.argv) != 4 or sys.argv[1] not in {"export", "restore"}:
        print("PILOT_ESCROW_PACKAGE_WRONG_PLATFORM_OR_ARGS")
        return 2
    mode = sys.argv[1]
    source, destination = Path(sys.argv[2]), Path(sys.argv[3])
    if mode == "export":
        if source != Path("/input") or destination != Path("/output") / PACKAGE_NAME:
            print("PILOT_ESCROW_PACKAGE_PATHS_UNEXPECTED")
            return 2
    elif source != Path("/input") / PACKAGE_NAME or destination != Path("/output"):
        print("PILOT_ESCROW_PACKAGE_PATHS_UNEXPECTED")
        return 2
    os.umask(0o077)
    try:
        require_dir(source if mode == "export" else source.parent)
        require_dir(destination.parent if mode == "export" else destination, empty=True)
        if mode == "export":
            files = {name: read_file(source / name, MAX_BYTES[name]) for name in ALL_NAMES}
            password = prompt(confirm=True)
            blob = seal(files, password)
            if unseal(blob, password) != files:
                raise ValueError("PACKAGE_SELF_CHECK_FAILED")
            write_new(destination, blob)
            print("PILOT_ESCROW_ENCRYPTED_PACKAGE_CREATED", flush=True)
            print(f"PILOT_ESCROW_PACKAGE_SHA256={hashlib.sha256(blob).hexdigest()}", flush=True)
        else:
            blob = read_file(source, MAX_PACKAGE_BYTES)
            files = unseal(blob, prompt(confirm=False))
            for name in ALL_NAMES:
                write_new(destination / name, files[name])
            print("PILOT_ESCROW_RESTORED_TO_NEW_DIRECTORY", flush=True)
        return 0
    except (OSError, UnicodeError, ValueError) as exc:
        print(str(exc), flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
