# copilot-api-plus packaging decision log

## Goal
Package `copilot-api-plus` in this NUR repo with nvfetcher-managed `0-unstable-YYYY-MM-DD` versioning, and avoid runtime network installation hacks.

## Final packaging approach
- Use npm tarball (`copilot-api-plus-1.2.25.tgz`) as source payload because it already contains `dist/` runtime artifacts.
- Keep NUR version sourced from nvfetcher commit date (`generated.copilot-api-plus.date`) to satisfy unstable version format.
- Use `buildNpmPackage` with a vendored production-only lockfile to produce offline `node_modules` in build sandbox.

## Why vendored lockfile is needed
Upstream lockfile includes broad dev graph metadata that led to npm offline cache misses during sandbox install (`ENOTCACHED` on dev-only packages). The package runtime only needs production dependencies.

To make `npm ci --omit=dev` deterministic in Nix sandbox:
- Provide `pkgs/copilot-api-plus/package-lock.json` containing only production dependency graph (with resolved/integrity entries).
- Rewrite unpacked `package.json` in `postPatch` to keep only runtime fields (`name`, `version`, `type`, `bin`, `dependencies`) so lockfile and package metadata stay consistent.

## Hashes
- npm source tarball hash: `sha256-23CrY5lP9x1zO2h1OuGJzfkB1MDHXjSgARkLPauzORo=`
- npm deps hash: `sha256-irGgVvkvaI+KZLK+xd/j2CiQfwyFPqPTUbwf3IAEqYg=`

## Validation
- `nix build .#copilot-api-plus` passes.
- Built binary `copilot-api-plus --help` runs successfully from Nix output.
