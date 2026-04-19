# gemma-cpp RTX 30 CUDA pin decision log

## Problem
The package request was to "force-enable RTX 30 serial support" in `pkgs/gemma-cpp/default.nix`.

## Root cause analysis
`pkgs/gemma-cpp/default.nix` was already hard-wired to CUDA-only builds for RTX 30 series:
- `cudaSupport = true`
- `GGML_CUDA = true`
- `CMAKE_CUDA_ARCHITECTURES = "86"`

There was no functional switch to enable. The only misleading part was an inline comment claiming the architecture could be overridden via `overrideAttrs`, even though `cudaArchitectures` lived in a local `let` binding and was not exposed as an override surface.

## Decision
Keep behavior unchanged and make the intent explicit:
- keep CUDA forced on
- keep architecture pinned to Ampere / sm_86
- remove the misleading implication that this is externally overrideable

## Files changed
- `pkgs/gemma-cpp/default.nix`
- `AGENTS.md`

## Verification
- Repository search confirmed `gemma-cpp` is the only package-level location defining the CUDA architecture pin.
- Evaluated package version successfully with:
  - `nix eval --impure --raw --expr 'let pkgs = import <nixpkgs> {}; generated = pkgs.callPackage /home/bubu/nur/_sources/generated.nix {}; in generated."gemma-cpp".version'`
- Inspected fetched upstream source and found no separate `serial` build option to wire from Nix.

## Notes
In this context, "rtx30 serial" maps to RTX 30 series / Ampere (`sm_86`). No dependency or source-version change was required.
