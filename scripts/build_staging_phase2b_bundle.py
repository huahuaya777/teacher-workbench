"""Create a separate deterministic offline staging source bundle for phase 2B.

The existing manual-queue and 2A deployment archives are never overwritten.
Only the reviewed source manifest and dependency wheels are included.
"""

from hashlib import sha256
from io import BytesIO
from pathlib import Path
import gzip
import tarfile

from build_staging_bundle import ROOT, manifest


OUTPUT = ROOT / "data" / "deploy" / "teacher-workbench-staging-phase2b.tar.gz"


def main():
    files = manifest()
    if OUTPUT.exists() or OUTPUT.is_symlink():
        raise RuntimeError("2B 归档已存在；拒绝覆盖，请先核对已有文件。")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("xb") as output_file:
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
        if [member.name for member in members] != [name for _, name in files] or any(not item.isfile() for item in members):
            raise RuntimeError("2B 归档清单不一致。")
    print(f"STAGING_PHASE2B_BUNDLE_FILES={len(files)}")
    print(f"STAGING_PHASE2B_BUNDLE_SHA256={sha256(OUTPUT.read_bytes()).hexdigest()}")
    print("STAGING_PHASE2B_BUNDLE_READY_LOCAL_ONLY")


if __name__ == "__main__":
    main()
