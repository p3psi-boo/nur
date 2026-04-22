# lucebox-hub packaging decision log

## Problem
Package `https://github.com/Luce-Org/lucebox-hub` in this NUR repository.

## Root cause analysis
The upstream repository is a documentation hub with two independent build targets:
- `megakernel/`: a PyTorch CUDA extension built through `setup.py`, with no lockfile or explicit dependency manifest.
- `dflash/`: a CMake CUDA project that produces the usable runtime binaries (`test_dflash`, `test_generate`) and the Python helper scripts that the README exposes.

Packaging the repo root as a single monolith would blur these boundaries. The smallest useful package surface is the `dflash` runtime plus its helper scripts.

A second issue is source reproducibility. `dflash` depends on the pinned `dflash/deps/llama.cpp` submodule, but this repository's `nvfetcher` output currently materializes the root source without submodules. The package therefore injects the exact pinned `llama.cpp` revision into the expected path during source preparation.

## Decision
Package `lucebox-hub` as a CUDA-only `dflash` runtime bundle:
- build `dflash/test_dflash` and `dflash/test_generate`
- ship the upstream Python helper scripts and REPL/server entrypoints
- expose wrapper commands (`lucebox-hub-run`, `lucebox-hub-server`, `lucebox-hub-chat`, benches)
- keep model weights external and configurable via `DFLASH_TARGET` / `DFLASH_DRAFT`
- pin CUDA kernels to `sm_86`, matching upstream and the repository's existing CUDA package policy
- carry local upstream adjustments as checked-in `.patch` files instead of inline mutation scripts so source deltas stay reviewable and reproducible

The `megakernel` subtree is intentionally not packaged in this first pass because upstream does not publish lockfiles or a stable Python packaging surface for it.

## Files changed
- `nvfetcher.toml`
- `_sources/generated.nix`
- `_sources/generated.json`
- `pkgs/lucebox-hub/default.nix`
- `pkgs/lucebox-hub/patches/0001-dflash-runtime-env-overrides.patch`
- `docs/ai/context/lucebox-hub-packaging.md`
- `AGENTS.md`

## Verification
- Added `lucebox-hub` to `nvfetcher` and regenerated `_sources/` with a filtered run.
- Prefetched the pinned `llama.cpp` submodule tarball and used its fixed hash in Nix.
- Runtime closure trims Hugging Face's test-only torch path by disabling `safetensors` checks inside the package-local Python scope. This avoids building `torch -> triton` when `lucebox-hub` only needs runtime imports.
- Evaluation/build verification should target:
  - `nix build .#lucebox-hub`
  - `nix build .#packages.x86_64-linux.lucebox-hub`

## Runtime notes
The package does not embed model weights. Users must provide:
- `DFLASH_TARGET=/path/to/Qwen3.5-27B-Q4_K_M.gguf`
- `DFLASH_DRAFT=/path/to/model.safetensors` or its snapshot directory

The packaged wrappers keep these paths external so the closure does not absorb multi-GB model artifacts.

## Patch policy
`pkgs/lucebox-hub` keeps runtime-path overrides in `pkgs/lucebox-hub/patches/0001-dflash-runtime-env-overrides.patch`.
This replaces the earlier inline Python rewrite step in `postPatch`, which was harder to audit and more brittle against upstream formatting drift.

## Dependency guardrails
The helper scripts need `transformers`, but current nixpkgs wires `safetensors` test inputs to `torch`, and `torch` in turn pulls `triton`. That path is irrelevant for `lucebox-hub` runtime execution and can fail spectacularly on memory-heavy Triton builds. The package therefore overrides only its local Python interpreter to disable `safetensors` checks, keeping the fix narrow and avoiding a repo-wide Python package policy change.

`run.py` and `server.py` also rely on `tokenizer.apply_chat_template(...)`, which requires `jinja2` at runtime. Missing `jinja2` manifests as:
- CLI: `ImportError: apply_chat_template requires jinja2`
- OpenAI server: HTTP 500 on `/v1/chat/completions`

The package-level Python environment now includes `jinja2` to make chat-template tokenization deterministic in both wrapper and server flows.

To keep interpreter behavior stable across nixpkgs updates, the package now binds explicitly to `python313` instead of relying on the floating `python3` alias.
