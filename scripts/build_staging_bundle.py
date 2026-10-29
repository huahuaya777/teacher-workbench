"""Package reviewed staging code and Linux wheels; exclude private data."""

from hashlib import sha256
from io import BytesIO
from pathlib import Path
import gzip
import tarfile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "deploy" / "teacher-workbench-staging.tar.gz"
TOP_LEVEL = (
    ".dockerignore",
    "compose.staging.yaml",
    "config/nginx-staging.conf",
    "Dockerfile.staging-offline",
    "manage.py",
    "requirements.txt",
    "staging.env.example",
    "scripts/check_test_env.py",
    "scripts/check_staging_env.py",
    "scripts/prepare_ubuntu_staging_env.py",
    "scripts/start_ubuntu_staging.sh",
    "scripts/verify_staging_http.py",
)
SOURCE_DIRS = ("config", "workbench", "templates")
SOURCE_SUFFIXES = {".py", ".html", ".css", ".js"}


def manifest() -> list[tuple[Path, str]]:
    files = [(ROOT / name, name) for name in TOP_LEVEL]
    for dirname in SOURCE_DIRS:
        for path in (ROOT / dirname).rglob("*"):
            if path.is_file() and path.suffix in SOURCE_SUFFIXES:
                files.append((path, path.relative_to(ROOT).as_posix()))
    wheels = sorted((ROOT / "data" / "wheelhouse").glob("*.whl"))
    if len(wheels) != 21:
        raise RuntimeError("离线依赖数量与已核对的 21 个 wheel 不符。")
    files.extend((path, f"wheelhouse/{path.name}") for path in wheels)
    names = [name for _, name in files]
    if len(names) != len(set(names)):
        raise RuntimeError("归档成员路径重复。")
    for path, name in files:
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
            raise RuntimeError(f"源文件缺失或越界：{name}")
        if path.stat().st_size > 20_000_000:
            raise RuntimeError(f"源文件过大：{name}")
    return sorted(files, key=lambda item: item[1])


def main() -> None:
    files = manifest()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("wb") as output_file:
        with gzip.GzipFile(filename="", mode="wb", fileobj=output_file, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                for path, name in files:
                    payload = path.read_bytes()
                    info = tarfile.TarInfo(name)
                    info.size = len(payload)
                    info.mode = 0o644
                    info.mtime = 0
                    archive.addfile(info, BytesIO(payload))
    with tarfile.open(OUTPUT, "r:gz") as archive:
        members = archive.getmembers()
        if [member.name for member in members] != [name for _, name in files]:
            raise RuntimeError("打包清单不一致。")
        if any(not member.isfile() or member.name.startswith("/") or ".." in Path(member.name).parts for member in members):
            raise RuntimeError("归档包含不安全路径。")
    print(f"STAGING_BUNDLE_FILES={len(files)}")
    print(f"STAGING_BUNDLE_BYTES={OUTPUT.stat().st_size}")
    print(f"STAGING_BUNDLE_SHA256={sha256(OUTPUT.read_bytes()).hexdigest()}")
    print("STAGING_BUNDLE_READY_LOCAL_ONLY")


if __name__ == "__main__":
    main()
