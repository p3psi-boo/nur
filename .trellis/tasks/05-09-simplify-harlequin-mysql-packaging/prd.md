# Simplify harlequin MySQL support packaging

## Goal

Simplify the recently added Harlequin MySQL support so users only see/use the overridden top-level `harlequin` package. The internal `harlequin-mysql` plugin derivation should not be exported as a public `python3Packages.harlequin-mysql` attribute or require users to know it exists.

## Requirements

* Keep top-level `.#harlequin` overriding nixpkgs Harlequin with MySQL/MariaDB adapter support.
* Hide the MySQL adapter derivation as an implementation detail inside the `harlequin` overlay.
* Remove now-unnecessary public Python extension plumbing for `harlequin-mysql`.
* Preserve existing nixpkgs Harlequin behavior and existing Postgres/BigQuery adapters.
* Do not edit `_sources/generated.{nix,json}`.

## Acceptance Criteria

* [x] `nix eval --raw .#harlequin.name` works.
* [x] `nix build .#harlequin --no-link` succeeds.
* [x] `harlequin --version` lists `mysql, version 1.3.0` among installed adapters.
* [x] `nix eval --expr 'let pkgs = import ./. { }; in pkgs.python3Packages ? harlequin-mysql'` or equivalent overlay check shows the plugin is not exported through the Python package set.
* [x] Modified Nix files are formatted with `nixfmt`.

## Technical Approach

Move the `harlequin-mysql` Python package definition from `python-packages/harlequin-mysql.nix` into a local `let` binding in `overlay.nix`'s `harlequinOverlay`. Append that local derivation to `prev.harlequin.overridePythonAttrs` dependencies. Revert `python-packages/default.nix` to its simpler aggregator signature and delete the standalone Python extension file.

## Out of Scope

* Removing the existing separate `pkgs/harlequin-mysql` package unless it proves necessary for hiding the Python extension.
* Changing nvfetcher sources.
* Upstreaming to nixpkgs.
