# MobilePi packaging research

## Upstream

Repository: https://github.com/p3psi-boo/MobilePi

MobilePi is a Dart/Flutter monorepo with:

* `hub/` — Dart CLI hub server, `pubspec.yaml` executable `hub: hub`.
* `node/` — Dart CLI daemon, `pubspec.yaml` executable `daemon: node`.
* `client/` — Flutter client, intentionally out of scope for this package.
* `shared/` — local Dart package dependency used by hub and node.

Upstream has no Git tags at inspection time, so use a git nvfetcher source with commit-date versions.

Upstream `flake.nix` already builds the CLI pieces with nixpkgs `buildDartApplication`:

```nix
hub = pkgs.buildDartApplication {
  pname = "hub";
  version = "0.1.0";
  inherit src;
  sourceRoot = "source/hub";
  autoPubspecLock = ./hub/pubspec.lock;
};

daemon = pkgs.buildDartApplication {
  pname = "daemon";
  version = "0.1.0";
  inherit src;
  sourceRoot = "source/node";
  autoPubspecLock = ./node/pubspec.lock;
};
```

## Repo conventions

This NUR repo passes `generated` automatically to packages whose directory name matches an nvfetcher entry. Package expressions should consume `generated.<pkg>.src` and `generated.<pkg>.version`; generated files are updated by running nvfetcher and must not be edited by hand.

## Packaging recommendation

Add `[mobilepi]` to `nvfetcher.toml` with `src.git`, `fetch.git`, `git.fetch_submodules = false`, and `git.get_commit_date = true`.

Add `pkgs/mobilepi/default.nix` that builds two internal derivations (`mobile-pi-hub`, `mobile-pi-node`) with `buildDartApplication`, then combines them using `symlinkJoin`. Since upstream executable names `hub` and `daemon` are generic, expose unambiguous `mobile-pi-hub` and `mobile-pi-node` symlinks in the final output.
