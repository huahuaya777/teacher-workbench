"""Start and supervise one PostgreSQL, Redis, web and queue worker instance."""
from datetime import datetime, timezone
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

from .runtime import DATA, KEYRING, configure_environment, initialize_secrets


def main():
    os.umask(0o077)
    children = []
    stopping = False
    ready = Path("/tmp/workbench-ready")
    ready.unlink(missing_ok=True)

    def stop(signum, frame):
        nonlocal stopping
        stopping = True

    def start(args):
        process = subprocess.Popen(args, start_new_session=True)
        children.append(process)
        return process

    def wait_for(probe, label):
        for _ in range(90):
            if stopping or any(child.poll() is not None for child in children):
                raise RuntimeError(f"Service stopped while waiting for {label}")
            try:
                probe()
                return
            except Exception:
                time.sleep(1)
        raise RuntimeError(f"Timed out waiting for {label}")

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        initialize_secrets()
        configure_environment()
        for directory in (DATA / "private", DATA / "redis", DATA / "backups", DATA / "socket"):
            directory.mkdir(mode=0o700, exist_ok=True)
        postgres = DATA / "postgres"
        if not (postgres / "PG_VERSION").exists():
            subprocess.run(["initdb", "-D", str(postgres), "-U", "workbench", "--auth-local=trust",
                            "--auth-host=scram-sha-256", "--pwfile=" + str(KEYRING / "database-password"),
                            "--encoding=UTF8", "--locale=C.UTF-8"], check=True)
        elif (postgres / "PG_VERSION").read_text().strip() != "17":
            raise RuntimeError("Database major version differs; use a logical dump/restore before upgrading")
        start(["postgres", "-D", str(postgres), "-h", "127.0.0.1", "-k", str(DATA / "socket"),
               "-c", "max_connections=30", "-c", "shared_buffers=64MB"])
        import psycopg

        def database_ready():
            with psycopg.connect(host="127.0.0.1", dbname="postgres", user="workbench",
                                 password=os.environ["DB_PASSWORD"], connect_timeout=1, autocommit=True) as db:
                if not db.execute("SELECT 1 FROM pg_database WHERE datname='workbench'").fetchone():
                    db.execute("CREATE DATABASE workbench")

        wait_for(database_ready, "PostgreSQL")
        start(["redis-server", "--bind", "127.0.0.1", "--protected-mode", "yes", "--save", "",
               "--appendonly", "yes", "--dir", str(DATA / "redis")])
        from redis import Redis
        wait_for(lambda: Redis(host="127.0.0.1", socket_connect_timeout=1).ping(), "Redis")
        import django
        django.setup()
        from django.core.management import call_command
        from django.db import connection
        from django.db.migrations.executor import MigrationExecutor
        executor = MigrationExecutor(connection)
        known = set(executor.loader.graph.nodes)
        if any(app == "workbench" and (app, name) not in known
               for app, name in executor.loader.applied_migrations):
            raise RuntimeError("Database schema is newer than this image; restore the matching backup before downgrading")
        if executor.migration_plan(executor.loader.graph.leaf_nodes()):
            if "workbench_worksheet" in connection.introspection.table_names():
                if os.getenv("TW_APPLY_MIGRATIONS", "0") != "1":
                    raise RuntimeError("Upgrade needs migrations: back up both stopped volumes, then set TW_APPLY_MIGRATIONS=1")
                backup = DATA / "backups" / ("pre-migrate-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + ".dump")
                subprocess.run(["pg_dump", "-h", "127.0.0.1", "-U", "workbench", "-Fc", "-f", str(backup), "workbench"],
                               env={**os.environ, "PGPASSWORD": os.environ["DB_PASSWORD"]}, check=True)
            call_command("migrate", interactive=False)
        call_command("check")
        # Do not keep a parent database socket when launching independent services.
        connection.close()
        start([sys.executable, "manage.py", "runworker"])
        start(["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2",
               "--timeout", "120", "--access-logfile", "-"])
        ready.write_text(" ".join(str(child.pid) for child in children))
        print("WORKBENCH_READY: create your own administrator with docker exec -it <container> python manage.py createsuperuser", flush=True)
        while not stopping:
            if any(child.poll() is not None for child in children):
                raise RuntimeError("A required service exited; stopping the container")
            time.sleep(1)
        return 0
    finally:
        ready.unlink(missing_ok=True)
        # Stop web and worker before Redis and PostgreSQL. Allow in-flight jobs to finish.
        deadline = time.monotonic() + 225
        for child in reversed(children):
            if child.poll() is not None:
                continue
            child.send_signal(signal.SIGINT if child is children[0] else signal.SIGTERM)
            try:
                child.wait(timeout=max(1, min(190, deadline - time.monotonic())))
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"WORKBENCH_STARTUP_FAILED: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise SystemExit(1)
