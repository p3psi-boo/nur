# Override harlequin with MySQL support

## Goal

Override nixpkgs' `harlequin` package in this NUR overlay so the exported `harlequin` application includes the upstream `harlequin-mysql` adapter. This should make MySQL/MariaDB support available from the `harlequin` CLI without replacing the user's command with a separate adapter-only package.

## What I already know

* nixpkgs already provides `harlequin` 2.5.2 with optional `withPostgresAdapter` and `withBigQueryAdapter` arguments, but no MySQL adapter option.
* This repository already has a generated `harlequin-mysql` source from nvfetcher (`tconbeer/harlequin-mysql`, version `v1.3.0`).
* This repository currently has `pkgs/harlequin-mysql/default.nix`, but it manually assembles site-packages using `uv-builder`; for integrating with nixpkgs `harlequin`, a normal Python package in `pythonPackagesExtensions` is more appropriate.
* nixpkgs provides `python3Packages.mysql-connector` 9.6.0 (the package name differs from PyPI's `mysql-connector-python`).
* Existing repo convention: Python package overrides/extensions are split into one file per package under `python-packages/` and aggregated by `python-packages/default.nix`.

## Requirements

* Add `harlequin-mysql` to the active Python package set through `pythonPackagesExtensions`.
* Override the top-level `harlequin` package exported by this overlay so its Python application dependencies include `python3Packages.harlequin-mysql`.
* Keep nixpkgs' existing `harlequin` behavior and adapters intact; only add MySQL support.
* Avoid direct edits to `_sources/generated.{nix,json}`; use the already generated nvfetcher entry.

## Acceptance Criteria

* [ ] `nix eval .#harlequin.name` resolves to a harlequin derivation from this overlay.
* [ ] The resulting `harlequin` derivation has `harlequin-mysql` in its Python dependencies.
* [ ] `nix build .#harlequin` succeeds or any failure is documented with a concrete upstream/nixpkgs reason.
* [ ] The `harlequin` CLI can import/register the MySQL adapter (for example via an import check or `harlequin --help` if feasible).
* [ ] `nixfmt` has been run on modified Nix files.

## Definition of Done

* Implementation is formatted and locally evaluated/built as far as practical.
* Existing generated source files remain untouched.
* Changes are limited to the overlay/Python packaging surface needed for this support.

## Technical Approach

Add `python-packages/harlequin-mysql.nix` defining `harlequin-mysql` with `buildPythonPackage`, `hatchling`, `mysql-connector`, and `pythonRemoveDeps = [ "harlequin" ]` to avoid the plugin/core circular dependency (matching nixpkgs' `harlequin-postgres` and `harlequin-bigquery` pattern). Import that extension from `python-packages/default.nix`.

Then override top-level `harlequin` in `overlay.nix` by applying `prev.harlequin.overridePythonAttrs` and appending `final.python3Packages.harlequin-mysql` to `dependencies`. Use `lib.optionals`/duplicate guards if needed to avoid duplicate dependencies.

## Decision (ADR-lite)

**Context**: `harlequin-mysql` is a plugin loaded through Python entry points; nixpkgs `harlequin` is a Python application with dependencies deciding which plugin distributions are installed.

**Decision**: Package `harlequin-mysql` as a Python package extension and override `harlequin` dependencies, rather than keeping a separate manually assembled adapter derivation.

**Consequences**: This follows nixpkgs' adapter pattern and preserves the `harlequin` command, but the overlay now depends on nixpkgs continuing to expose a Python-application `harlequin` with `overridePythonAttrs` and a compatible dependency layout.

## Out of Scope

* Upstreaming a new `withMySQLAdapter` option to nixpkgs.
* Adding or modifying nvfetcher sources unless the current generated source is unusable.
* Running live MySQL/MariaDB integration tests.

## Technical Notes

* Relevant files: `overlay.nix`, `python-packages/default.nix`, new `python-packages/harlequin-mysql.nix`.
* nixpkgs references inspected:
  * `/nix/store/ps8fhbglachs62pf47aw3rzx8zfij8sp-source/pkgs/by-name/ha/harlequin/package.nix`
  * `/nix/store/ps8fhbglachs62pf47aw3rzx8zfij8sp-source/pkgs/development/python-modules/harlequin-postgres/default.nix`
  * `/nix/store/ps8fhbglachs62pf47aw3rzx8zfij8sp-source/pkgs/development/python-modules/mysql-connector/default.nix`
