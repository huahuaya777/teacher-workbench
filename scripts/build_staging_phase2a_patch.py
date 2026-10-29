"""Package only stage-2A code, with no accounts, keys, or teaching files."""

from hashlib import sha256
from io import BytesIO
from pathlib import Path
import gzip
import tarfile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data" / "deploy" / "teacher-workbench-staging-phase2a.tar.gz"
NAMES = (
    "config/settings.py",
    "workbench/models.py",
    "workbench/forms.py",
    "workbench/urls.py",
    "workbench/member_views.py",
    "workbench/member_middleware.py",
    "workbench/migrations/0004_memberaccess_memberaudit.py",
    "workbench/tests_accounts.py",
    "templates/base.html",
    "templates/workbench/member_list.html",
    "templates/workbench/member_secret_once.html",
    "templates/workbench/member_change_password.html",
    "workbench/static/workbench/site.css",
    "scripts/prepare_ubuntu_staging_phase2a_manager.py",
)


def main():
    files = sorted(NAMES)
    for name in files:
        path = ROOT / name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
            raise RuntimeError(f"补丁源文件缺失或越界：{name}")
        if path.stat().st_size > 200_000:
            raise RuntimeError(f"补丁源文件过大：{name}")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("wb") as output:
        with gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                for name in files:
                    payload = (ROOT / name).read_bytes()
                    info = tarfile.TarInfo(name)
                    info.size = len(payload)
                    info.mode = 0o644
                    info.mtime = 0
                    archive.addfile(info, BytesIO(payload))
    with tarfile.open(OUTPUT, "r:gz") as archive:
        members = archive.getmembers()
        if [member.name for member in members] != files or any(not item.isfile() for item in members):
            raise RuntimeError("补丁清单不一致。")
    print(f"STAGING_PHASE2A_PATCH_FILES={len(files)}")
    print(f"STAGING_PHASE2A_PATCH_SHA256={sha256(OUTPUT.read_bytes()).hexdigest()}")
    print("STAGING_PHASE2A_PATCH_READY_LOCAL_ONLY")


if __name__ == "__main__":
    main()
