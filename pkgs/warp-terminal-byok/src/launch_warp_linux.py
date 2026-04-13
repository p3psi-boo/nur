#!/usr/bin/env python3
"""
Launch Warp on Linux with local AI shim proxy.
Configuration is loaded from XDG config path only.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from urllib.request import urlopen

from warp_platform import (
    LINUX_DEFAULT_CONFIG_DIR,
    LINUX_DEFAULT_CONFIG_PATH,
    get_runtime_paths,
)

DEFAULT_RUNTIME_PATHS = get_runtime_paths()


def get_warp_binary(args_warp_path: str | None) -> Path:
    """Get Warp binary from argument, environment, or PATH."""
    if args_warp_path:
        path = Path(args_warp_path)
        if path.exists():
            return path
        raise RuntimeError(f"Warp binary not found: {path}")

    if env_path := os.environ.get("WARP_BINARY"):
        path = Path(env_path)
        if path.exists():
            return path
        raise RuntimeError(f"WARP_BINARY not found: {env_path}")

    import shutil
    if path_str := shutil.which("warp-terminal"):
        return Path(path_str)

    raise RuntimeError("Warp binary not found. Set WARP_BINARY or use --warp-path")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Launch Warp on Linux with BYOK support.",
    )
    parser.add_argument(
        "--warp-path",
        help="Path to Warp binary (default: $WARP_BINARY or warp-terminal from PATH)",
    )
    parser.add_argument("--foreground", action="store_true", help="Run shim in foreground")
    return parser


def wait_for_shim(host: str, port: int, timeout: float = 10.0) -> None:
    """Wait for shim proxy to be ready."""
    health_url = f"http://{host}:{port}/__warp_shim/health"
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        try:
            with urlopen(health_url, timeout=1.0) as response:
                if response.status == 200:
                    return
        except Exception:
            pass
        time.sleep(0.2)

    raise RuntimeError(f"Shim failed to start within {timeout} seconds")


def start_shim(config: dict, foreground: bool) -> subprocess.Popen:
    """Start the shim proxy server."""
    LINUX_DEFAULT_CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    # Write config to XDG config path
    with open(LINUX_DEFAULT_CONFIG_PATH, "w") as f:
        json.dump(config, f, indent=2)

    shim_cmd = [
        sys.executable,
        str(Path(__file__).parent / "warp_shim.py"),
        "--config", str(LINUX_DEFAULT_CONFIG_PATH),
    ]

    stdout = None if foreground else subprocess.DEVNULL
    stderr = None if foreground else subprocess.DEVNULL

    shim_process = subprocess.Popen(
        shim_cmd,
        stdout=stdout,
        stderr=stderr,
        start_new_session=not foreground,
    )

    try:
        listen_host = config.get("listen_host", "127.0.0.1")
        listen_port = config.get("listen_port", 8911)
        wait_for_shim(listen_host, listen_port)
        print(f"✓ Shim proxy running at http://{listen_host}:{listen_port}")
    except RuntimeError:
        shim_process.terminate()
        raise

    return shim_process


def launch_warp(warp_binary: Path, shim_host: str, shim_port: int) -> subprocess.Popen:
    """Launch Warp with shim proxy configuration."""
    env = os.environ.copy()
    shim_url = f"http://{shim_host}:{shim_port}"

    # Standard proxy environment variables
    for key in ["HTTP_PROXY", "http_proxy", "HTTPS_PROXY", "https_proxy"]:
        env[key] = shim_url

    # Warp-specific configuration
    env["WARP_SERVER_ROOT_URL"] = shim_url
    env["WARP_WS_SERVER_URL"] = f"ws://{shim_host}:{shim_port}"
    env["WARP_SESSION_SHARING_SERVER_URL"] = shim_url

    print(f"Launching Warp: {warp_binary}")
    print(f"  HTTP_PROXY={shim_url}")

    return subprocess.Popen([str(warp_binary)], env=env)


def load_or_create_config() -> dict:
    """Load config from XDG config path or return defaults."""
    if LINUX_DEFAULT_CONFIG_PATH.exists():
        with open(LINUX_DEFAULT_CONFIG_PATH) as f:
            return json.load(f)

    # Return default config
    return {
        "listen_host": "127.0.0.1",
        "listen_port": 8911,
        "upstream_http_base": "https://app.warp.dev",
        "upstream_ws_base": "wss://rtc.app.warp.dev/graphql/v2",
        "upstream_ai_base": "https://app.warp.dev",
        "log_path": str(DEFAULT_RUNTIME_PATHS.log_path),
    }


def main() -> int:
    args = build_parser().parse_args()

    # Get Warp binary
    try:
        warp_binary = get_warp_binary(args.warp_path)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    # Load or create config
    config = load_or_create_config()

    # Ensure required config keys exist
    required_keys = ["openai_api_key", "anthropic_api_key", "google_api_key"]
    if not any(k in config and config[k] for k in required_keys):
        print("Error: No API key configured.", file=sys.stderr)
        print(f"Please edit: {LINUX_DEFAULT_CONFIG_PATH}", file=sys.stderr)
        print("\nExample configuration:", file=sys.stderr)
        print(json.dumps({
            "listen_host": "127.0.0.1",
            "listen_port": 8911,
            "openai_api_key": "sk-...",
            "openai_base_url": "https://api.openai.com/v1",
        }, indent=2), file=sys.stderr)
        return 1

    print("Starting Warp AI shim proxy...")
    try:
        shim_process = start_shim(config, args.foreground)
    except RuntimeError as e:
        print(f"Error starting shim: {e}", file=sys.stderr)
        return 1

    listen_host = config.get("listen_host", "127.0.0.1")
    listen_port = config.get("listen_port", 8911)

    try:
        warp_process = launch_warp(warp_binary, listen_host, listen_port)
    except RuntimeError as e:
        print(f"Error launching Warp: {e}", file=sys.stderr)
        shim_process.terminate()
        return 1

    print("\n✓ Warp is running with BYOK support!")
    print(f"  - Shim proxy: http://{listen_host}:{listen_port}")
    print(f"  - Config: {LINUX_DEFAULT_CONFIG_PATH}")
    print("\nPress Ctrl+C to stop.")

    try:
        warp_process.wait()
    except KeyboardInterrupt:
        print("\nShutting down...")
        warp_process.terminate()
        shim_process.terminate()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
