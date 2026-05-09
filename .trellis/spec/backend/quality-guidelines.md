# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Required Patterns

<!-- Patterns that must always be used -->

### Repository Python package extensions

**Scope / Trigger**: When adding or overriding Python packages for this NUR overlay.

**Signatures**:

- Aggregator: `python-packages/default.nix` returns `{ pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [ ... ]; }`.
- Extension file shape:
  ```nix
  { final, ... }:
  python-final: python-prev: {
    package-name = python-final.buildPythonPackage { ... };
    existing-package = python-prev.existing-package.overridePythonAttrs (_old: { ... });
  }
  ```
- Top-level overlay import may pass extra arguments (for example `generated`) when an extension needs nvfetcher sources.

**Contracts**:

- `default.nix` only aggregates extensions; keep package logic in a dedicated `python-packages/<name>.nix` file.
- Use `python-final` for Python dependencies/build helpers and `python-prev` when overriding existing Python packages.
- If a Python plugin depends on the application that will include it, remove that dependency in the plugin package (for example `pythonRemoveDeps = [ "harlequin" ];`) and verify it through the final application package to avoid dependency cycles.
- Do not edit `_sources/generated.{nix,json}` directly; consume `generated.<pkg>.src` / `generated.<pkg>.version` from nvfetcher output.

**Good/Base/Bad Cases**:

- Good: add `python-packages/harlequin-mysql.nix`, import it from `python-packages/default.nix`, then add it to the consuming app's dependencies in `overlay.nix`.
- Base: simple existing-package override in one extension file, imported by `default.nix`.
- Bad: manually copying site-packages into a separate derivation when the goal is to make a Python application see a plugin distribution.

**Tests Required**:

- `nixfmt` on modified Nix files.
- `nix eval` that proves the extension is visible in the relevant Python package set or top-level package dependencies.
- `nix build` of the final consumer package when practical.

**Wrong vs Correct**:

Wrong:
```nix
# Separate adapter derivation; the main app will not see plugin entry points.
stdenv.mkDerivation { installPhase = "cp -r src/plugin $out/..."; }
```

Correct:
```nix
# Python extension + final app dependency, so Python entry points are installed together.
python-final.buildPythonPackage { pname = "plugin"; ...; }
```

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
