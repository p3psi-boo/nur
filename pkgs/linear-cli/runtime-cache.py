"""Copy only the CLI's reachable npm packages and locked JSR modules."""

import json
import pathlib
import shutil
import sys


graph = json.loads(pathlib.Path(sys.argv[1]).read_text())
cache = pathlib.Path(sys.argv[2])
out = pathlib.Path(sys.argv[3])
lock_path = pathlib.Path("deno.lock")
lock = json.loads(lock_path.read_text())
packages = graph["npmPackages"]
pending = [module["npmPackage"] for module in graph["modules"] if module["kind"] == "npm"]
seen = set()
while pending:
    key = pending.pop()
    if key not in seen:
        seen.add(key)
        pending.extend(packages[key]["dependencies"])

for key in sorted(seen):
    path = pathlib.Path(packages[key]["localPath"])
    target = out / path.relative_to(cache)
    if not target.exists():
        shutil.copytree(
            path, target,
            # Retain package manifests/licenses, but not type declarations or
            # debugging maps: the installed CLI runs without type checking.
            ignore=shutil.ignore_patterns("*.d.ts", "*.d.mts", "*.d.cts", "*.map"),
        )

lock["npm"] = {key: value for key, value in lock["npm"].items() if key in seen}
lock["specifiers"] = {
    key: value for key, value in lock["specifiers"].items()
    if not key.startswith("npm:") or (key[4:].rsplit("@", 1)[0] + "@" + value) in seen
}
lock_path.write_text(json.dumps(lock, indent=2) + "\n")

# Preserve JSR manifests/checksums as well as source files. Some test-related
# std modules are real transitive CLI dependencies, so use the resolved lock
# rather than deleting packages based on names like "assert".
urls = set()
prefixes = []
for key in lock["jsr"]:
    name, version = key.rsplit("@", 1)
    base = "https://jsr.io/" + name + "/"
    urls.update((base + "meta.json", base + version + "_meta.json"))
    prefixes.append(base + version + "/")

marker = b"\n// denoCacheMetadata="
for path in (cache / "remote").rglob("*"):
    if not path.is_file():
        continue
    _, separator, raw = path.read_bytes().rpartition(marker)
    if not separator:
        raise ValueError(f"Missing Deno cache metadata: {path}")
    url = json.loads(raw)["url"]
    if not url.startswith("https://jsr.io/"):
        raise ValueError(f"Review new non-JSR runtime dependency: {url}")
    if url in urls or url.startswith(tuple(prefixes)):
        target = out / path.relative_to(cache)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)

print(f"Runtime npm packages: {len(seen)} (build cache: {len(packages)})")
