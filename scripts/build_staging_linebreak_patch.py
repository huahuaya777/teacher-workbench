"""Package only the reviewed staging rendering fix; no private data."""

from hashlib import sha256
from io import BytesIO
from pathlib import Path
import gzip
import tarfile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "deploy" / "teacher-workbench-staging-linebreak-fix.tar.gz"
NAMES = (
    "workbench/export.py",
    "workbench/templatetags/worksheet_display.py",
)


def main():
    for name in NAMES:
        path = ROOT / name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
            raise RuntimeError(f"补丁源文件缺失或越界：{name}")
        if path.stat().st_size > 100_000:
            raise RuntimeError(f"补丁源文件过大：{name}")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("wb") as target:
        with gzip.GzipFile(filename="", mode="wb", fileobj=target, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                for name in sorted(NAMES):
                    payload = (ROOT / name).read_bytes()
                    info = tarfile.TarInfo(name)
                    info.size = len(payload)
                    info.mode = 0o644
                    info.mtime = 0
                    archive.addfile(info, BytesIO(payload))
    with tarfile.open(OUTPUT, "r:gz") as archive:
        members = archive.getmembers()
        if [member.name for member in members] != sorted(NAMES) or any(not member.isfile() for member in members):
            raise RuntimeError("补丁清单不一致。")
    print(f"STAGING_LINEBREAK_PATCH_SHA256={sha256(OUTPUT.read_bytes()).hexdigest()}")
    print("STAGING_LINEBREAK_PATCH_READY_LOCAL_ONLY")


if __name__ == "__main__":
    main()
