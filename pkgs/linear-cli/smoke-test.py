"""Exercise the installed CLI against a local GraphQL fixture, without credentials."""

import http.server
import json
import os
import pathlib
import tempfile
import subprocess
import sys
import threading


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        assert self.headers["Authorization"] == "fixture-token"
        assert "query" in request
        payload = json.dumps({"data": {
            "viewer": {"id": "fixture-user"},
            "teams": {"nodes": [], "pageInfo": {"hasNextPage": False}},
        }}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_args):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
env = os.environ | {
    "LINEAR_API_KEY": "fixture-token",
    "LINEAR_GRAPHQL_ENDPOINT": f"http://127.0.0.1:{server.server_port}/graphql",
    "LINEAR_IGNORE_ENV_FILE": "1",
    "NO_COLOR": "1",
}


def run(*args):
    result = subprocess.run(
        [sys.argv[1], *args], env=env, text=True, capture_output=True,
        check=True, timeout=30,
    )
    assert not result.stderr, result.stderr
    return result.stdout


try:
    assert json.loads(run("api", "query { viewer { id } }"))["data"]["viewer"]["id"] == "fixture-user"
    # Exercises graphql-request and the dynamic Spinner import, not just --help.
    assert "No teams found" in run("team", "list")
    assert "markdown" in run("markdown").lower()
finally:
    server.shutdown()
    server.server_close()
    thread.join()
print("Installed CLI smoke tests passed")

# Test the installed Markdown stack too (unified/remark/unist and charmd),
# using only the pruned runtime cache, not any build-time packages.
app = pathlib.Path(sys.argv[1]).parent.parent / "share/linear-cli"
module = (app / "src/utils/markdown-images.ts").as_uri()
script = f"""
import {{ extractImageInfo, replaceImageUrls }} from {json.dumps(module)};
import {{ renderMarkdown }} from "@littletof/charmd";
const input = "![fixture](https://example.invalid/image.png)";
const images = extractImageInfo(input);
if (images.length !== 1 || images[0].alt !== "fixture") throw Error("image parse");
const text = await replaceImageUrls(input, new Map([[images[0].url, "local.png"]]));
if (!text.includes("local.png")) throw Error("image replacement");
if (!renderMarkdown("# Fixture").includes("Fixture")) throw Error("markdown render");
"""
with tempfile.TemporaryDirectory() as directory:
    entrypoint = pathlib.Path(directory) / "check.ts"
    entrypoint.write_text(script)
    subprocess.run(
        [sys.argv[2], "run", "--quiet", "--cached-only", "--frozen", "--no-check",
         "-A", "--config", str(app / "deno.json"), str(entrypoint)],
        env=env | {"DENO_DIR": str(app / "cache")}, check=True, timeout=30,
    )
print("Installed Markdown runtime tests passed")
