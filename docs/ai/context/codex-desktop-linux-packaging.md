# codex-desktop-linux packaging decision log

## Goal
Package `codex-desktop-linux` into this NUR repository, aligned with repo conventions (`nvfetcher` source tracking + `0-unstable-YYYY-MM-DD` versioning), while preserving NixOS runtime compatibility for upstream Electron artifacts.

## Final packaging approach
- Add `codex-desktop-linux` to `nvfetcher.toml` as a git source with commit date enabled.
- Implement `pkgs/codex-desktop-linux/default.nix` as a **runtime installer wrapper** (not a fully prebuilt app derivation).
- Bundle upstream project sources into `$out/share/codex-desktop-linux/source`.
- Pin and fetch upstream DMG via `fetchurl`:
  - URL: `https://persistent.oaistatic.com/codex-app-prod/Codex.dmg`
  - Hash: `sha256-ZdMRQRfx8DFX4paDWOfBu6ykjz/kqbybcfxvcZ6XAus=`
- Expose `codex-desktop-linux` wrapper in `$out/bin` that:
  1. Copies sources + DMG into a writable temp workdir.
  2. Runs upstream `install.sh` with `CODEX_INSTALL_DIR` (default `./codex-app`).
  3. Rewrites generated `codex-app/start.sh` shebang from `/bin/bash` to Nix store bash.
  4. Patches generated Electron binaries via `patchelf` (`interpreter` + `rpath`) to use NixOS runtime libs.
- Add desktop integration artifacts:
  - launcher: `$out/bin/codex-desktop-linux-launcher`
  - desktop entry: `$out/share/applications/codex-desktop-linux.desktop`
  - icon: `$out/share/icons/hicolor/256x256/apps/codex-desktop-linux.png`

The launcher design keeps first-run UX predictable:
- if `CODEX_INSTALL_DIR/start.sh` exists, run it directly;
- otherwise fall back to `codex-desktop-linux` installer flow.

## Why runtime wrapper instead of full build in derivation
Upstream install flow is intentionally mutable and writes build outputs into local directories (`codex-app/`), including runtime rebuild steps using npm tooling. Keeping that behavior outside Nix store avoids:
- write-protection conflicts against immutable store paths,
- embedding large, user-specific generated app payload into derivation outputs,
- divergence from upstream update/install expectations.

This keeps the package maintainable while still delivering a reproducible launcher entry point and NixOS-specific ELF patching.

## NixOS compatibility details
The wrapper applies post-install binary patching to generated `codex-app`:
- `electron`: set dynamic linker + rpath to include app dir and required Electron GTK/X11/system libs.
- `chrome_crashpad_handler` / `chrome-sandbox`: set dynamic linker.
- top-level `*.so*`: set rpath to Electron runtime libs.

This mirrors upstream flake intent while keeping repository integration consistent with existing NUR packaging patterns.

## Versioning and source tracking
- Version format: `0-unstable-${generated.codex-desktop-linux.date}`.
- `generated.codex-desktop-linux` is produced from `nvfetcher` and provides `src` + `date`.

## Validation
- `nix build .#codex-desktop-linux --no-link` passes.
- `nix run .#codex-desktop-linux -- --help` prints upstream installer usage and exits successfully.
