#!/usr/bin/env python3
"""Linux platform support for Warp shim (nix-optimized)."""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path


def is_linux() -> bool:
    return sys.platform.startswith("linux")


# Linux default paths (XDG Base Directory specification)
LINUX_DEFAULT_CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
LINUX_DEFAULT_DATA_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
LINUX_DEFAULT_CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))

# Warp-specific paths
LINUX_WARP_CONFIG_DIR = LINUX_DEFAULT_CONFIG_DIR / "warp"
LINUX_WARP_DATA_DIR = LINUX_DEFAULT_DATA_DIR / "warp"
LINUX_DEFAULT_CONFIG_PATH = LINUX_WARP_CONFIG_DIR / "warp-shim.json"
LINUX_DEFAULT_LOG_PATH = LINUX_DEFAULT_CACHE_DIR / "warp-shim.log"
LINUX_DEFAULT_STDERR_LOG_PATH = LINUX_DEFAULT_CACHE_DIR / "warp-shim.stderr.log"
LINUX_DEFAULT_CAPTURE_DIR = LINUX_DEFAULT_CACHE_DIR / "warp-shim-captures"

LINUX_SECURE_STORAGE_DIR = LINUX_WARP_CONFIG_DIR
LINUX_SECURE_STORAGE_SERVICE = "dev.warp.Warp-Stable"


@dataclass(frozen=True)
class WarpRuntimePaths:
    install_path: Path
    config_path: Path
    preferences_path: Path | None
    log_path: Path
    stderr_log_path: Path
    capture_dir: Path
    sqlite_path: Path
    secure_storage_dir: Path | None
    secure_storage_service: str
    real_executable_name: str


def normalize_user_path(path_like: str | os.PathLike[str] | Path) -> Path:
    """Normalize a user-provided path, expanding variables and home directory."""
    raw_path = os.path.expandvars(os.path.expanduser(os.fspath(path_like)))
    return Path(raw_path)


def resolve_warp_install_path(path_like: str | os.PathLike[str] | Path | None = None) -> Path:
    """Resolve Warp installation path."""
    if path_like is None:
        return Path("/opt/warpdotdev/warp-terminal")
    return normalize_user_path(path_like).resolve()


def get_runtime_paths(install_path: Path | None = None) -> WarpRuntimePaths:
    """Get Linux runtime paths."""
    effective = resolve_warp_install_path(install_path)
    return WarpRuntimePaths(
        install_path=effective,
        config_path=LINUX_DEFAULT_CONFIG_PATH,
        preferences_path=None,
        log_path=LINUX_DEFAULT_LOG_PATH,
        stderr_log_path=LINUX_DEFAULT_STDERR_LOG_PATH,
        capture_dir=LINUX_DEFAULT_CAPTURE_DIR,
        sqlite_path=LINUX_WARP_DATA_DIR / "warp.sqlite",
        secure_storage_dir=LINUX_SECURE_STORAGE_DIR,
        secure_storage_service=LINUX_SECURE_STORAGE_SERVICE,
        real_executable_name="warp",
    )


def get_executable_path(install_path: Path) -> Path:
    """Get the Warp executable path for Linux."""
    resolved = resolve_warp_install_path(install_path)
    candidates = [
        resolved / "warp",
        resolved,
        Path("/opt/warpdotdev/warp-terminal/warp"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise RuntimeError(f"Warp executable not found: {resolved}")


def _get_storage_file(service: str, account: str, storage_dir: Path | None) -> Path:
    """Get the path to a secure storage file."""
    directory = storage_dir or LINUX_SECURE_STORAGE_DIR
    return directory / f"{service}-{account}.json"


def load_secure_storage_json(service: str, account: str, storage_dir: Path | None = None) -> dict[str, object]:
    """Load secure storage data from Linux file-based storage."""
    storage_file = _get_storage_file(service, account, storage_dir)
    if not storage_file.exists():
        return {}
    try:
        with open(storage_file, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, IOError):
        return {}


def save_secure_storage_json(
    service: str,
    account: str,
    storage_dir: Path | None,
    data: dict[str, object],
) -> None:
    """Save secure storage data to Linux file-based storage."""
    directory = storage_dir or LINUX_SECURE_STORAGE_DIR
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    storage_file = directory / f"{service}-{account}.json"
    with open(storage_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.chmod(storage_file, 0o600)
