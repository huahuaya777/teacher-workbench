"""Build an allowlisted source archive for the isolated Ubuntu test stack.

The output stays under the Git-ignored data/ directory. Never add private
materials, local databases, credentials, or handoff files to this archive.
"""

from __future__ import annotations

import hashlib
import io
import tarfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "deploy" / "teacher-workbench-test.tar.gz"
TOP_LEVEL = (
    ".dockerignore",
    ".env.example",
    "compose.yaml",
    "Dockerfile",
    "manage.py",
    "requirements.txt",
    "scripts/check_test_env.py",
)
SOURCE_DIRS = ("config", "workbench", "templates")
ALLOWED_SUFFIXES = {".py", ".html", ".css", ".js"}
MAX_FILE_BYTES = 2_000_000


def source_files() -> list[Path]:
    files = [ROOT / name for name in TOP_LEVEL]
    for dirname in SOURCE_DIRS:
        files.extend(
            path
            for path in (ROOT / dirname).rglob("*")
            if path.is_file() and path.suffix in ALLOWED_SUFFIXES
        )
    files.sort(key=lambda path: path.relative_to(ROOT).as_posix())
    for path in files:
        if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_FILE_BYTES:
            raise RuntimeError(f"不安全或缺失的源文件：{path.relative_to(ROOT)}")
        if not path.resolve().is_relative_to(ROOT):
            raise RuntimeError(f"源文件越过项目目录：{path}")
    return files


def main() -> None:
    files = source_files()
    expected = {path.relative_to(ROOT).as_posix() for path in files}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(OUTPUT, "w:gz") as archive:
        for path in files:
            payload = path.read_bytes()
            name = path.relative_to(ROOT).as_posix()
            info = tarfile.TarInfo(name)
            info.size = len(payload)
            info.mode = 0o644
            info.mtime = 0
            archive.addfile(info, io.BytesIO(payload))

    with tarfile.open(OUTPUT, "r:gz") as archive:
        actual = {item.name for item in archive.getmembers()}
        if actual != expected or any(not item.isfile() for item in archive.getmembers()):
            raise RuntimeError("归档内容与允许的源文件清单不一致。")

    digest = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    print(f"测试包：{OUTPUT}")
    print(f"文件数：{len(files)}；大小：{OUTPUT.stat().st_size} 字节；SHA-256：{digest}")
    print("归档成员均来自明确允许的代码与示例配置路径；尚未上传或运行。")


if __name__ == "__main__":
    main()
