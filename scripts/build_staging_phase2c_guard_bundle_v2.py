"""Build a separate v2 archive after the PostgreSQL queue assertion fix."""

from hashlib import sha256
from io import BytesIO
from pathlib import Path
import gzip
import tarfile

from build_staging_phase2c_pg_bundle import ROOT, source_manifest


OUTPUT = ROOT / "data" / "deploy" / "teacher-workbench-stage2c-guard-v2-source.tar.gz"
REQUIRED = {
    "workbench/management/commands/reconcile_member_calls.py",
    "workbench/tests_reconcile_member_calls.py",
    "workbench/tests_member_flow.py",
    "workbench/tests_member_tasks.py",
    "workbench/tests_pg_call_gate.py",
}


def main():
    entries = source_manifest()
    if not REQUIRED.issubset({name for _, name in entries}):
        raise RuntimeError("2C 安全闸门源码不完整。")
    if OUTPUT.exists() or OUTPUT.is_symlink():
        raise RuntimeError("2C 安全闸门归档已存在；拒绝覆盖。")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("xb") as target:
        with gzip.GzipFile(filename="", fileobj=target, mode="wb", mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                for path, name in entries:
                    payload = path.read_bytes()
                    info = tarfile.TarInfo(name)
                    info.size = len(payload)
                    info.mode = 0o644
                    info.mtime = 0
                    archive.addfile(info, BytesIO(payload))
    with tarfile.open(OUTPUT, "r:gz") as archive:
        members = archive.getmembers()
        if [item.name for item in members] != [name for _, name in entries] or any(
            not item.isfile() or item.issym() or item.islnk() for item in members
        ):
            raise RuntimeError("2C 安全闸门归档校验失败。")
    print(f"STAGING_2C_GUARD_V2_SOURCE_FILES={len(entries)}")
    print(f"STAGING_2C_GUARD_V2_SOURCE_SHA256={sha256(OUTPUT.read_bytes()).hexdigest()}")
    print("STAGING_2C_GUARD_V2_SOURCE_READY_LOCAL_ONLY")


if __name__ == "__main__":
    main()
