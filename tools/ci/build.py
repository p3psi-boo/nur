#!/usr/bin/env python3
"""Build checks and publish bounded, build-corroborated package hash repairs."""
import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

HASH = re.compile(r'"(sha(?:256|512)-[A-Za-z0-9+/]+=*)"')
MISMATCH = re.compile(
    r"hash mismatch in fixed-output derivation [^\n]+:\s*"
    r"specified:\s*(\S+)\s*got:\s*(\S+)"
)
BRANCH = "automation/nixpkgs-sync"


def git(*args, env=None):
    return subprocess.check_output(["git", *args], text=True, env=env).strip()


def trusted():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    pull = event.get("pull_request", {})
    return (os.environ["GITHUB_EVENT_NAME"] == "pull_request"
            and pull["head"]["repo"]["full_name"] == os.environ["GITHUB_REPOSITORY"]
            and pull["head"]["ref"] == BRANCH
            and pull["user"]["login"] == os.environ["GITHUB_REPOSITORY_OWNER"]
            and pull["base"]["ref"] == "main"
            and pull["head"]["sha"] == git("rev-parse", "HEAD"))


def verify_changes(files):
    changed = set(filter(None, git("diff", "HEAD", "--name-only", "-z").split("\0")))
    if (changed != set(files) or git("diff", "HEAD", "--summary")
            or git("ls-files", "--others", "--exclude-standard")):
        raise ValueError("Checkout contains changes outside the verified hash repairs")
    for name, digest in files.items():
        path = Path(name)
        if (not name.startswith("pkgs/") or path.suffix != ".nix"
                or path.resolve() != path.absolute()
                or hashlib.sha256(path.read_bytes()).hexdigest() != digest):
            raise ValueError("Verified package changed after hash repair")


def repair(since, pairs):
    originals = {}
    for name in filter(None, git("ls-files", "-z", "--", "pkgs/*.nix").split("\0")):
        path = Path(name)
        if path.resolve() == path.absolute() and path.is_file():
            originals[name] = path.read_bytes()
    changes = {}
    # Only copies of tracked package expressions reach the fixer; nvfetcher output never does.
    with tempfile.TemporaryDirectory(prefix="nur-hashes-") as directory:
        staging = Path(directory)
        for name, content in originals.items():
            target = staging / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        subprocess.run(["determinate-nixd", "fix", "hashes", "--auto-apply",
                        "--since", since, str(staging)], check=True, timeout=60,
                       stdin=subprocess.DEVNULL)
        for name, before in originals.items():
            after = (staging / name).read_bytes()
            if before == after:
                continue
            old_parts, new_parts = HASH.split(before.decode()), HASH.split(after.decode())
            if old_parts[::2] != new_parts[::2] or len(old_parts) != len(new_parts):
                raise ValueError("Hash fixer changed more than SRI hash literals")
            for old, new in zip(old_parts[1::2], new_parts[1::2]):
                if old != new and (old, new) not in pairs:
                    raise ValueError("Hash replacement is absent from this build's mismatch log")
            changes[name] = after
    for name, after in changes.items():
        if Path(name).read_bytes() != originals[name]:
            raise ValueError("Package changed while the fixer was running")
    for name, after in changes.items():
        Path(name).write_bytes(after)
    return changes


def build():
    if git("status", "--porcelain"):
        raise ValueError("Build requires a clean checkout")
    root = Path(os.environ["RUNNER_TEMP"])
    files = {}
    nix = shutil.which("nix")
    nix_build = shutil.which("nix-build")
    if not nix or not nix_build:
        raise ValueError("Determinate Nix executables are required")
    # nix-fast-build's wrapper prepends upstream Nix; pin the installed Determinate executables.
    command = [nix, "shell", "--no-update-lock-file", "--inputs-from", ".",
               "nixpkgs#nix-fast-build", "--command", "nix-fast-build", "--nix", nix,
               "--nix-build", nix_build, "--flake", ".#checks.x86_64-linux",
               "--eval-workers", "2", "--eval-max-memory-size", "2048", "--max-jobs", "2",
               "--option", "cores", "2", "--skip-cached", "--no-nom",
               "--result-file", str(root / "nur-build.json")]
    for attempt in range(3):
        since = datetime.now(timezone.utc).isoformat(timespec="microseconds")
        log = root / f"nur-build-{attempt}.log"
        with log.open("w") as stream, subprocess.Popen(
                command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, errors="replace") as process:
            for line in process.stdout:
                print(line, end="", flush=True)
                stream.write(line)
            code = process.wait()
        verify_changes(files)
        if code == 0:
            results = json.loads((root / "nur-build.json").read_text())["results"]
            if not results or any(result["success"] is not True for result in results):
                raise ValueError("Build report does not contain exclusively successful results")
            (root / "nur-repair.json").write_text(json.dumps({
                "head": git("rev-parse", "HEAD"), "files": files,
            }) + "\n")
            with Path(os.environ["GITHUB_OUTPUT"]).open("a") as stream:
                stream.write(f"repaired={str(bool(files)).lower()}\n")
            return
        if code < 0 or not trusted() or attempt == 2:
            raise RuntimeError(f"Package build failed (exit {code}); no further automatic repairs")
        text = re.sub(r"\x1b\[[0-9;]*m", "", log.read_text())
        # nix-fast-build prefixes every line of each package's error with '<attribute>> '.
        text = re.sub(r"(?m)^[^\n>]+> ", "", text)
        pairs = set(MISMATCH.findall(text))
        if not pairs:
            raise RuntimeError("Build failed without a fixed-output hash mismatch")
        changes = repair(since, pairs)
        if not changes:
            raise RuntimeError("No unique tracked package hash fix; regenerate nvfetcher sources separately")
        for name, after in changes.items():
            files[name] = hashlib.sha256(after).hexdigest()
        verify_changes(files)


def publish():
    state = json.loads((Path(os.environ["RUNNER_TEMP"]) / "nur-repair.json").read_text())
    if not state["files"]:
        return
    if not trusted() or git("rev-parse", "HEAD") != state["head"]:
        raise ValueError("Only the verified synchronization PR head can receive hash repairs")
    verify_changes(state["files"])
    token = os.environ.get("NUR_SYNC_TOKEN", "")
    if not token:
        raise ValueError("NUR_SYNC_TOKEN is required to push repairs and trigger fresh CI")
    remote = git("ls-remote", "--heads", "origin", "refs/heads/" + BRANCH)
    if not remote or remote.split()[0] != state["head"]:
        raise ValueError("Synchronization branch advanced; discard this stale hash repair")
    git("config", "user.name", "NUR dependency bot")
    git("config", "user.email", "nur-bot@users.noreply.github.com")
    git("add", "--", *state["files"])
    git("commit", "-m", "fix: repair package hashes for synchronized nixpkgs")
    auth = base64.b64encode(("x-access-token:" + token).encode()).decode()
    env = os.environ | {
        "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "http.https://github.com/.extraheader",
        "GIT_CONFIG_VALUE_0": "Authorization: Basic " + auth, "GIT_TERMINAL_PROMPT": "0",
    }
    git("push", "origin", "HEAD:refs/heads/" + BRANCH, env=env)
    raise RuntimeError("Hash repairs pushed; require the new commit's complete CI run")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in ("build", "publish"):
            raise ValueError("Usage: build.py build|publish")
        {"build": build, "publish": publish}[sys.argv[1]]()
    except (ValueError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
