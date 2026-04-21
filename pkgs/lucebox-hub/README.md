# lucebox-hub

Nix packaging notes for [`Luce-Org/lucebox-hub`](https://github.com/Luce-Org/lucebox-hub).

This package currently ships the **`dflash/` runtime only**:
- `test_dflash`
- `test_generate`
- helper scripts and wrappers for run/server/chat/bench flows

It intentionally does **not** package `megakernel/` in this first pass.

## Package scope

The upstream repository is a documentation hub with two separate build targets:
- `megakernel/` — PyTorch CUDA extension
- `dflash/` — CMake/CUDA runtime

The packaged surface here is the smallest useful runtime bundle from `dflash/`.

## Build characteristics

- **Platform:** `x86_64-linux`
- **License:** MIT
- **CUDA architecture:** `sm_86` (Ampere / RTX 30 class target)
- **Versioning:** `0-unstable-YYYY-MM-DD` via `nvfetcher`

## Installation

With this NUR overlay enabled:

```nix
environment.systemPackages = with pkgs; [
  lucebox-hub
];
```

Ad-hoc build:

```bash
nix build .#packages.x86_64-linux.lucebox-hub
```

## Installed commands

| Command | Purpose |
| --- | --- |
| `lucebox-hub-run` | Streaming one-shot generation wrapper |
| `lucebox-hub-server` | OpenAI-compatible HTTP server wrapper |
| `lucebox-hub-chat` | Multi-turn chat REPL wrapper |
| `lucebox-hub-bench-he` | HumanEval-oriented benchmark helper |
| `lucebox-hub-bench-llm` | Multi-dataset benchmark helper |
| `lucebox-hub-dflash` | Raw `test_dflash` binary |
| `lucebox-hub-generate` | Raw `test_generate` binary |

## Runtime model paths

Model weights stay outside the Nix closure.

Set these before running the wrappers:

```bash
export DFLASH_TARGET=/path/to/Qwen3.5-27B-Q4_K_M.gguf
export DFLASH_DRAFT=/path/to/model.safetensors
```

`DFLASH_DRAFT` may also point at the corresponding Hugging Face snapshot directory.

The wrappers inject `DFLASH_BIN` automatically so the Python entrypoints resolve the packaged store binary instead of assuming an in-tree build directory.

## Implementation notes

- The pinned `dflash/deps/llama.cpp` submodule is injected during source preparation because the current `nvfetcher` materialization of `lucebox-hub` does not carry submodule contents into `generated.lucebox-hub.src`.
- Runtime path overrides are maintained in `patches/0001-dflash-runtime-env-overrides.patch` so the upstream helper scripts remain reviewable as static source deltas.
- The package builds static-output binaries with `BUILD_SHARED_LIBS=OFF` to avoid leaking build-directory RPATHs into the final closure.

## Non-goals

This package does not:
- bundle model weights
- generalize CUDA architectures beyond the current upstream target
- package the `megakernel/` subtree

For packaging rationale and maintenance history, see `docs/ai/context/lucebox-hub-packaging.md`.
