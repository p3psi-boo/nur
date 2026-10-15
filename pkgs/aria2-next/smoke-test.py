"""Exercise CLI downloads and authenticated JSON-RPC without external network access."""

import functools
import http.client
import http.server
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request


def main():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        payload = bytes(range(256)) * 4096
        (root / "payload.bin").write_bytes(payload)
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = f"http://127.0.0.1:{server.server_port}/payload.bin"
        common = [
            "aria2-next",
            "--no-conf=true",
            "--enable-dht=false",
            "--enable-peer-exchange=false",
            "--bt-enable-lpd=false",
            "--bt-port-mapping=false",
            "--ed2k-port-mapping=false",
            f"--dir={root}",
        ]
        try:
            subprocess.run(
                common + [f"--state-dir={root / 'cli-state'}", "--out=cli.bin", url],
                check=True,
                timeout=30,
            )
            assert (root / "cli.bin").read_bytes() == payload

            with socket.socket() as sock:
                sock.bind(("127.0.0.1", 0))
                rpc_port = sock.getsockname()[1]

            def rpc(method, *params):
                request = urllib.request.Request(
                    f"http://127.0.0.1:{rpc_port}/jsonrpc",
                    data=json.dumps({
                        "jsonrpc": "2.0",
                        "id": 1,
                        "method": f"aria2.{method}",
                        "params": ["token:smoke-test", *params],
                    }).encode(),
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(request, timeout=2) as response:
                    result = json.load(response)
                assert "error" not in result, result
                return result["result"]

            process = subprocess.Popen(common + [
                f"--state-dir={root / 'rpc-state'}",
                "--enable-rpc=true",
                "--rpc-listen-all=false",
                f"--rpc-listen-port={rpc_port}",
                "--rpc-secret=smoke-test",
            ])
            try:
                deadline = time.monotonic() + 30
                while True:
                    assert process.poll() is None, "RPC server exited early"
                    try:
                        version = rpc("getVersion")
                        assert version["version"]
                        break
                    except urllib.error.URLError:
                        if time.monotonic() >= deadline:
                            raise
                        time.sleep(0.1)
                gid = rpc("addUri", [url], {"out": "rpc.bin"})
                deadline = time.monotonic() + 30
                while True:
                    status = rpc("tellStatus", gid)
                    assert status["status"] != "error", status
                    if status["status"] == "complete":
                        break
                    assert time.monotonic() < deadline, status
                    time.sleep(0.1)
                assert (root / "rpc.bin").read_bytes() == payload
                try:
                    rpc("shutdown")
                except http.client.RemoteDisconnected:
                    # 3.0.4 can stop the HTTP server before flushing the reply.
                    pass
                assert process.wait(timeout=10) == 0
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    main()
