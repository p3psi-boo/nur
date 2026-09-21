"""Remove mutable registry metadata and HTTP headers from the Deno fetch cache."""

import json
import pathlib
import sys


root = pathlib.Path(sys.argv[1])
lock = json.loads(pathlib.Path(sys.argv[2]).read_text())
# Frozen/offline npm resolution uses the lockfile, not registry packuments.
for path in (root / "npm").rglob("registry.json"):
    path.unlink()

marker = b"\n// denoCacheMetadata="
for path in (root / "remote").rglob("*"):
    if not path.is_file():
        continue
    body, separator, raw = path.read_bytes().rpartition(marker)
    if not separator:
        raise ValueError(f"Missing cache metadata: {path}")
    metadata = json.loads(raw)
    if metadata["url"].endswith("/meta.json"):
        # JSR still reads package manifests in cached-only mode. Retain only
        # locked versions, excluding mutable latest/creation-time metadata.
        data = json.loads(body)
        name = "@" + data["scope"] + "/" + data["name"]
        versions = sorted(
            key.rsplit("@", 1)[1] for key in lock["jsr"]
            if key.rsplit("@", 1)[0] == name
        )
        data = {
            "scope": data["scope"], "name": data["name"],
            "latest": versions[-1], "versions": {version: {} for version in versions},
        }
        body = json.dumps(data, sort_keys=True, separators=(",", ":")).encode()
    metadata = {
        "url": metadata["url"],
        "headers": {
            key: value for key, value in metadata["headers"].items()
            if key in ("content-type", "location", "x-typescript-types")
        },
        "time": 0,
    }
    path.write_bytes(
        body + marker + json.dumps(metadata, sort_keys=True, separators=(",", ":")).encode()
    )
