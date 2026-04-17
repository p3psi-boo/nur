# komari runtime version mismatch fix

## Problem
`pkgs/komari` package metadata version is derived from nvfetcher date, but runtime-reported version stayed at upstream defaults (`0.0.1` / `unknown`).

User-visible impact:
- Startup log prints wrong version/hash.
- `/api/version` returns wrong version/hash.

## Root cause
Upstream keeps placeholders in `utils/version.go` and expects build-time `-ldflags -X` injection.

In this repository, `pkgs/komari/default.nix` previously set only strip flags (`-s -w`) and did not inject version variables.

## Decision
Inject runtime version fields at build time in `komariBackend.ldflags`:
- `github.com/komari-monitor/komari/utils.CurrentVersion=${backendVersion}`
- `github.com/komari-monitor/komari/utils.VersionHash=${backendCommit}`

Also normalize package-level version source with a shared binding:
- `backendVersion = "0-unstable-${generated.komari.date}"`
- `backendCommit = generated.komari.version`

## Files changed
- `pkgs/komari/default.nix`
- `AGENTS.md`

## Verification
- Evaluated target package version:
  - `nix eval .#packages.x86_64-linux.komari.version`
  - Result: `"0-unstable-2026-04-14"`
- Ran repository-level flake evaluation check (`nix flake check --no-build --keep-going`):
  - `packages.x86_64-linux.komari` evaluates successfully.
  - Check still fails due to unrelated pre-existing package issues (`micyou`, `dbhub`, `rime-custom-pinyin-dictionary`, `cloudflarespeedtest`, `kernel-rss-opt-patches`).

## Notes
This is a runtime metadata correctness fix only. No source bump or dependency changes were introduced.