"""Boot the immutable package against disposable PostgreSQL and Redis."""

import base64
import json
import os
import secrets
import signal
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


with tempfile.TemporaryDirectory(prefix="infisical-smoke-") as directory:
    root = Path(directory)
    pg_port, redis_port, http_port = free_port(), free_port(), free_port()
    env = os.environ | {
        "HOME": str(root),
        "TMPDIR": str(root),
        "ENCRYPTION_KEY": secrets.token_hex(16),
        "AUTH_SECRET": base64.b64encode(secrets.token_bytes(32)).decode(),
        "DB_CONNECTION_URI": f"postgresql://infisical@127.0.0.1:{pg_port}/infisical",
        "REDIS_URL": f"redis://127.0.0.1:{redis_port}",
        "HOST": "127.0.0.1",
        "PORT": str(http_port),
        "SITE_URL": f"http://127.0.0.1:{http_port}",
        "TELEMETRY_ENABLED": "false",
        "DISABLE_UPDATE_CHECK": "true",
        "OTEL_TELEMETRY_COLLECTION_ENABLED": "false",
    }
    processes = []
    logs = []

    def start(name, *args):
        log = open(root / f"{name}.log", "w+")
        logs.append(log)
        process = subprocess.Popen(args, env=env, stdout=log, stderr=log)
        processes.append(process)
        return process

    def wait_until(check, timeout=120):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for process in processes:
                assert process.poll() is None, f"Service exited: {process.args}"
            if check():
                return
            time.sleep(0.5)
        raise TimeoutError("Service did not become ready")

    def tcp_ready(port):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=1):
                return True
        except OSError:
            return False

    def get(path):
        with urllib.request.urlopen(env["SITE_URL"] + path, timeout=5) as response:
            assert response.status == 200
            return response.read()

    def http_ready():
        try:
            get("/api/status")
            return True
        except (OSError, urllib.error.URLError):
            return False

    try:
        run("initdb", "-D", str(root / "pg"), "-U", "infisical",
            "--auth=trust", "--no-locale", "--encoding=UTF8", env=env)
        # Disposable test data only: avoid fsync for every historical migration.
        start("postgres", "postgres", "-D", str(root / "pg"), "-h", "127.0.0.1",
              "-p", str(pg_port), "-k", str(root), "-c", "fsync=off",
              "-c", "synchronous_commit=off", "-c", "full_page_writes=off")
        wait_until(lambda: tcp_ready(pg_port))
        run("createdb", "-h", "127.0.0.1", "-p", str(pg_port), "-U", "infisical", "infisical", env=env)
        start("redis", "redis-server", "--bind", "127.0.0.1", "--port", str(redis_port),
              "--save", "", "--appendonly", "no", "--dir", str(root))
        wait_until(lambda: tcp_ready(redis_port))
        print("PostgreSQL and Redis ready; starting Infisical and migrations", flush=True)
        server = start("infisical", "infisical-server")
        wait_until(http_ready, timeout=240)
        status = json.loads(get("/api/status"))
        assert status["message"] == "Ok", status
        assert status["redisConfigured"] is True, status
        assert b"<html" in get("/").lower(), "Web UI missing"
        assert b"__INFISICAL_RUNTIME_ENV__" in get("/runtime-ui-env.js")
        migrations = subprocess.check_output(
            ["psql", env["DB_CONNECTION_URI"], "-Atc", "SELECT count(*) FROM infisical_migrations"],
            env=env, text=True,
        )
        assert int(migrations.strip()) > 0, "Migrations did not run"
        print(f"HTTP status/UI/runtime config OK; {migrations.strip()} migrations; status={status}")
        server.send_signal(signal.SIGTERM)
        assert server.wait(timeout=30) == 0, "Server did not shut down cleanly"

        # A second boot must work against an already-migrated database.
        processes.remove(server)
        server = start("infisical-restart", "infisical-server")
        wait_until(http_ready, timeout=120)
        server.send_signal(signal.SIGTERM)
        assert server.wait(timeout=30) == 0
        print("Restart and graceful shutdown OK")
    except BaseException:
        for log in logs:
            log.flush()
            log.seek(0)
            print(f"\n--- {log.name} ---\n{log.read()[-18000:]}")
        raise
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for log in logs:
            log.close()
