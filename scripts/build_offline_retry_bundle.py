"""Package only Linux wheels and test-only retry files into ignored data/."""

from __future__ import annotations

import hashlib
import io
import tarfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WHEELS = ROOT / "data" / "wheelhouse"
OUTPUT = ROOT / "data" / "deploy" / "teacher-workbench-test-offline-retry.tar.gz"
SOURCES = (
    (ROOT / "Dockerfile.test-offline", "Dockerfile.test-offline"),
    (ROOT / "scripts" / "retry_ubuntu_test_stack_offline.sh", "retry_ubuntu_test_stack_offline.sh"),
)


def main() -> None:
    wheels = sorted(WHEELS.glob("*.whl"))
    if len(wheels) != 18 or len(list(WHEELS.iterdir())) != len(wheels):
        raise RuntimeError("离线 wheelhouse 必须只包含已核对的 18 个 wheel。")
    files = [*SOURCES, *((p, f"wheelhouse/{p.name}") for p in wheels)]
    for source, _ in files:
        if source.is_symlink() or not source.is_file() or not source.resolve().is_relative_to(ROOT):
            raise RuntimeError(f"不安全的文件：{source}")
        if source.stat().st_size > 20_000_000:
            raise RuntimeError(f"文件过大：{source}")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(OUTPUT, "w:gz") as archive:
        for source, name in files:
            data = source.read_bytes()
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o644
            info.mtime = 0
            archive.addfile(info, io.BytesIO(data))
    with tarfile.open(OUTPUT, "r:gz") as archive:
        members = archive.getmembers()
        if [m.name for m in members] != [name for _, name in files] or any(not m.isfile() for m in members):
            raise RuntimeError("重试包清单核验失败。")
    digest = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    print(f"OFFLINE_RETRY_FILE_COUNT={len(files)}")
    print(f"OFFLINE_RETRY_BYTES={OUTPUT.stat().st_size}")
    print(f"OFFLINE_RETRY_SHA256={digest}")


if __name__ == "__main__":
    main()
