"""Separate upstream's development configuration from the installed CLI."""

import json
import pathlib
import sys


def write(path, data):
    pathlib.Path(path).write_text(json.dumps(data, indent=2) + "\n")


config = json.loads(pathlib.Path("deno.json").read_text())
if sys.argv[1] == "build":
    # Git hook installation is never part of building or running this package.
    config["imports"].pop("lefthook")
    lock = json.loads(pathlib.Path("deno.lock").read_text())
    lock["specifiers"] = {
        key: value for key, value in lock["specifiers"].items()
        if not key.startswith("npm:lefthook@")
    }
    lock["npm"] = {
        key: value for key, value in lock["npm"].items()
        if not key.startswith(("lefthook@", "lefthook-"))
    }
    lock["workspace"]["dependencies"] = [
        value for value in lock["workspace"]["dependencies"]
        if not value.startswith("npm:lefthook@")
    ]
    write("deno.lock", lock)
else:
    # Transpilation removes type-only imports. Preserve filenames so upstream's
    # relative imports (including extensionless generated imports) stay valid.
    for path in pathlib.Path("transpiled/src").rglob("*.js"):
        target = pathlib.Path("src") / path.relative_to("transpiled/src").with_suffix(".ts")
        target.write_bytes(path.read_bytes())
    excluded = {
        "lefthook", "@graphql-codegen/cli", "@cliffy/testing",
        "@std/testing", "@std/assert", "@types/mdast", "mdast",
        "@graphql-typed-document-node/core",
    }
    config["imports"] = {
        key: value for key, value in config["imports"].items()
        if key not in excluded
    }
    # Keep runtime resolution settings and the version imported by the CLI,
    # not upstream's codegen/lint/test/install tasks and publishing settings.
    config = {key: config[key] for key in ("version", "imports", "unstable")}
write("deno.json", config)
