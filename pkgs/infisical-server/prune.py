"""Prune the vendor dependency tree offline, without npm resolution or scripts."""

import json
import shutil
import sys
from pathlib import Path


root = Path(sys.argv[1])
lock = json.loads((root / "package-lock.json").read_text())
assert lock["lockfileVersion"] == 3
for name, package in lock["packages"].items():
    # npm's lock records dev-only dependencies, including nested copies.
    if package.get("dev") is True and name.startswith("node_modules/"):
        path = root / name
        assert ".." not in path.parts
        shutil.rmtree(path, ignore_errors=True)

modules = root / "node_modules"
for prebuilds in modules.glob("**/prebuilds"):
    for platform in prebuilds.iterdir():
        if platform.is_dir() and platform.name not in ("linux-x64", "linuxglibc-x64"):
            shutil.rmtree(platform)

# Some native packages put every OS/libc variant beside one another.
for binary in modules.rglob("*.node"):
    if any(marker in binary.name for marker in ("darwin", "win32", "arm64", "musl")):
        binary.unlink()

# Native addons ship their node-gyp build intermediates as well as the loadable
# .node files. Object files/static archives are not runtime inputs.
for path in modules.rglob("*"):
    if "build" in path.parts and path.suffix in (".o", ".a") and path.is_file():
        path.unlink()

# Pruning dev packages leaves their .bin links behind.
for path in modules.rglob("*"):
    if path.is_symlink() and not path.exists():
        path.unlink()
