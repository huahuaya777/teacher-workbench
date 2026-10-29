"""Package only the reviewed login change for a disposable Ubuntu test run."""

from hashlib import sha256
from io import BytesIO
from pathlib import Path
import tarfile


ROOT = Path(__file__).resolve().parent.parent
FILES = (
    "config/settings.py",
    "config/urls.py",
    "config/admin_app.py",
    "config/admin_site.py",
    "workbench/auth_views.py",
    "workbench/tests.py",
    "templates/registration/login.html",
)


def main() -> None:
    target = ROOT / "data" / "test-bundles" / "teacher-workbench-login-throttle-bundle.tar.gz"
    target.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(target, "w:gz") as archive:
        for name in FILES:
            data = (ROOT / name).read_bytes()
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o600
            info.mtime = 0
            archive.addfile(info, BytesIO(data))
    print(f"LOGIN_BUNDLE_SHA256={sha256(target.read_bytes()).hexdigest()}")
    print("LOGIN_BUNDLE_FILES=" + ",".join(FILES))


if __name__ == "__main__":
    main()
