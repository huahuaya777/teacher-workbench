"""Create a minimal, deterministic source archive for isolated PostgreSQL tests.

Only application source and fictional tests are included. No .env, wheelhouse,
database, uploaded material, keyring, or backup path can enter the manifest.
"""

from hashlib import sha256
from io import BytesIO
from pathlib import Path
import gzip
import tarfile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "deploy" / "teacher-workbench-stage2c-pg-source.tar.gz"
ROOT_FILES = ("manage.py", "requirements.txt")
SOURCE_DIRS = ("config", "workbench", "templates")
SUFFIXES = {".py", ".html", ".css", ".js"}


def source_manifest():
    entries = [(ROOT / name, name) for name in ROOT_FILES]
    for dirname in SOURCE_DIRS:
        for path in (ROOT / dirname).rglob("*"):
            if path.is_file() and path.suffix in SUFFIXES:
                entries.append((path, path.relative_to(ROOT).as_posix()))
    names = [name for _, name in entries]
    if len(names) != len(set(names)) or not any(name == "workbench/tests_pg_call_gate.py" for name in names):
        raise RuntimeError("2C 源码清单缺失或重复。")
    for path, name in entries:
        if (path.is_symlink() or not path.is_file() or
                not path.resolve().is_relative_to(ROOT) or
                path.stat().st_size > 2_000_000 or
                name.startswith("/") or ".." in Path(name).parts):
            raise RuntimeError(f"2C 源码路径或大小不安全：{name}")
    return sorted(entries, key=lambda entry: entry[1])


def main():
    entries = source_manifest()
    if OUTPUT.exists() or OUTPUT.is_symlink():
        raise RuntimeError("2C PostgreSQL 源码归档已存在，拒绝覆盖。")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("xb") as target:
        with gzip.GzipFile(filename="", mode="wb", fileobj=target, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                for path, name in entries:
                    content = path.read_bytes()
                    info = tarfile.TarInfo(name)
                    info.size = len(content)
                    info.mode = 0o644
                    info.mtime = 0
                    archive.addfile(info, BytesIO(content))
    with tarfile.open(OUTPUT, "r:gz") as archive:
        members = archive.getmembers()
        if ([member.name for member in members] != [name for _, name in entries] or
                any(not member.isfile() or member.name.startswith("/") or
                    ".." in Path(member.name).parts for member in members)):
            raise RuntimeError("2C PostgreSQL 归档内容校验失败。")
    print(f"STAGING_2C_PG_SOURCE_FILES={len(entries)}")
    print(f"STAGING_2C_PG_SOURCE_BYTES={OUTPUT.stat().st_size}")
    print(f"STAGING_2C_PG_SOURCE_SHA256={sha256(OUTPUT.read_bytes()).hexdigest()}")
    print("STAGING_2C_PG_SOURCE_READY_LOCAL_ONLY")


if __name__ == "__main__":
    main()
