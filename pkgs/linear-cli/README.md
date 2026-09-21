# linear-cli

Builds upstream TypeScript from one nvfetcher-managed source for
`x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.

## Dependency split

- `buildDeps` is a fixed-output Deno cache. It follows the upstream lockfile,
  removes Lefthook entirely, and normalizes mutable registry/HTTP metadata.
  GraphQL codegen and test dependencies exist only in this build input.
- The regular sandboxed derivation generates GraphQL code and runs 43 selected
  upstream CLI/credentials/keyring tests.
- Installation transpiles application TypeScript to erase type-only imports
  without bundling (bundling this release produces a circular-initialization
  failure). Original filenames are retained to preserve relative imports.
- Runtime configuration drops build/test/type-only import aliases. The offline
  dependency graph selects the npm dependency closure; the pruned JSR lock
  selects JSR modules. Transitive assertions used by the CLI remain included.
- Type declarations, source maps, test tooling, codegen, and disposable
  V8/SQLite caches are not installed. Required npm package metadata and licenses
  are retained, including metadata for transitive type-only dependencies.
- The wrapper uses nixpkgs Deno with `--cached-only --frozen --no-check`.
  Linux adds `secret-tool` from libsecret for credential storage. Git, jj,
  gh, editors, and browsers remain optional user-provided workflow tools.

Install checks exercise the CLI, shell completions, a local mock GraphQL server,
dynamic imports, and the installed Markdown processing dependencies. The output
must not reference the build dependency cache, Python, or the build-time Git.

## Updating

From the parent nixcfg checkout:

```sh
nix develop ./nur -c nvfetcher --filter '^linear-cli$' \
  -o nur/_sources -c nur/nvfetcher.toml --keyfile ./keyfile.toml
nix build ./nur#linear-cli
```

When dependencies change, replace `buildDeps.outputHash` with `lib.fakeHash`,
build `./nur#linear-cli.buildDeps`, and use the reported recursive SHA-256.
Then rebuild the application and its dependency cache with `--rebuild` to check
reproducibility. Deno cache format changes may require updating
`normalize-cache.py`; do not suppress lockfile or checksum verification.

Validation performed on x86_64 Linux. ARM Linux and ARM Darwin derivations were
evaluated; native execution on those platforms remains to be checked. The three
targets' dependency fetches were also compared using Deno's `--os`/`--arch` and
produced the same normalized build-cache hash after removing Lefthook.
