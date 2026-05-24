# Package MobilePi for NUR

## Goal

Add p3psi-boo/MobilePi to this NUR repository so the Dart CLI components can be built and exposed as Nix packages.

## Requirements

* Add a `mobilepi` package under `pkgs/`.
* Use nvfetcher-managed source metadata from `nvfetcher.toml`; do not edit `_sources/generated.{nix,json}` by hand.
* Package the Dart AOT CLI components provided by upstream:
  * Hub (`hub/`, executable `hub`)
  * Daemon / node (`node/`, executable `daemon`)
* The package should expose runnable binaries with unambiguous `mobile-pi-` prefixes: `mobile-pi-hub` and `mobile-pi-node`.
* Do not attempt to package the Flutter mobile client / Android APK in this task.

## Acceptance Criteria

* [ ] `nvfetcher.toml` contains a `mobilepi` source entry for `https://github.com/p3psi-boo/MobilePi`.
* [ ] `nvfetcher -o _sources -c ./nvfetcher.toml --keyfile ./keyfile.toml` has regenerated source metadata.
* [ ] `pkgs/mobilepi/default.nix` builds both Dart CLI components from the shared upstream source.
* [ ] `nixfmt` has formatted modified Nix files.
* [ ] `nix build .#mobilepi` succeeds.
* [ ] At least one binary smoke check (`--help` or equivalent no-network command if available) is attempted or documented if not possible.

## Definition of Done

* Nix package builds in this NUR repo.
* Relevant generated nvfetcher files are updated by nvfetcher.
* Changes are checked and ready to commit.

## Technical Approach

Use upstream's Dart package structure. Upstream already has a Nix flake using `buildDartApplication` for `hub` and `node`, with `sourceRoot = "source/hub"` and `sourceRoot = "source/node"`. Reuse that approach in this NUR package, consuming `generated.mobilepi.src` / `generated.mobilepi.version`.

A top-level `mobilepi` derivation can combine the two component derivations with `symlinkJoin` and rename/link the generated executables to `mobile-pi-hub` and `mobile-pi-node`, because upstream binary names are generic (`hub` and `daemon`).

## Out of Scope

* Building the Flutter mobile/web client.
* Creating NixOS modules or services for hub/daemon.
* Pushing the parent `nixcfg` repository; only NUR packaging is in scope.

## Technical Notes

* `nh search MobilePi` returned no matching nixpkgs package.
* Upstream has no Git tags at time of inspection; use unstable nvfetcher Git source/version.
* Upstream `flake.nix` declares package version `0.1.0` for `hub` and `daemon` but source version should remain nvfetcher-managed.
* Upstream path layout: `hub/pubspec.lock`, `node/pubspec.lock`, `shared/pubspec.yaml`.
