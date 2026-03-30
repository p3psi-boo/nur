{
  lib,
  stdenv,
  generated,
  nodejs_22,
  nodejs-slim_22,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:

let
  sourceInfo = generated.bird-cli;
  runtimeNode = nodejs-slim_22;
  pnpm = pnpm_10;
  gitSha =
    let
      rev = sourceInfo.rev or null;
    in
    if rev != null && (lib.match "^[0-9a-f]{8,40}$" rev) != null then
      builtins.substring 0 8 rev
    else
      "unknown";

  # Map Nix system tuples to the npm/pnpm identifiers.
  # pnpm uses these to filter platform-specific optional dependencies,
  # preventing the fetcher from downloading binaries for every OS/arch.
  npmOs = builtins.elemAt (lib.splitString "-" stdenv.hostPlatform.system) 1;
  npmCpu =
    let
      arch = builtins.elemAt (lib.splitString "-" stdenv.hostPlatform.system) 0;
    in
    {
      x86_64 = "x64";
      aarch64 = "arm64";
      i686 = "ia32";
      armv7l = "arm";
    }
    .${arch} or arch;

  # Inject supportedArchitectures into .npmrc so pnpm only fetches deps
  # for the current host platform.  Eliminates ~20 unused @rollup/* and
  # fsevents downloads that inflate the pnpmDeps fixed-output derivation.
  setPnpmArch = ''
    echo "supportedArchitectures.os=[\"${npmOs}\"]" >> .npmrc
    echo "supportedArchitectures.cpu=[\"${npmCpu}\"]" >> .npmrc
    echo "auto-install-peers=true" >> .npmrc
  '';

  srcWithLock = stdenv.mkDerivation {
    pname = "bird-cli-src";
    inherit (sourceInfo) version src;
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      cp -r "$src" "$out"
      chmod -R u+w "$out"
      cp ${./pnpm-lock.yaml} "$out/pnpm-lock.yaml"
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "bird-cli";
  version = "0-unstable-${sourceInfo.date}";
  src = srcWithLock;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm;
    fetcherVersion = 1;
    hash = "sha256-NRzbBZAy2lZTz2gt2ztl6B0r521ryKYDEgkppnqiC6M=";
    prePnpmInstall = setPnpmArch;
    # Only fetch production deps; devDeps are not needed at runtime
    # and significantly bloat the fixed-output derivation.
    NODE_ENV = "production";
  };

  prePnpmInstall = setPnpmArch;

  nativeBuildInputs = [
    nodejs_22
    pnpmConfigHook
    pnpm
    makeWrapper
  ];

  # Prevent pnpm from pulling devDeps during the configure phase.
  # Combined with NODE_ENV in fetchPnpmDeps, this ensures only runtime
  # dependencies enter the build closure.
  NODE_ENV = "production";

  buildPhase = ''
    runHook preBuild

    # Build dist/ so we can run the CLI via Node.
    #
    # NOTE: bun's `--compile` output behaves like the bun CLI in this Nix build,
    # which breaks `bird --help` / `bird --version`.
    pnpm run build:dist

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # The built entrypoint is ESM and may carry a duplicated shebang.
    # Keep exactly one shebang and provide `require` via createRequire.
    sed -i '2{/^#!\/usr\/bin\/env node$/d;}' dist/cli.js
    sed -i '2i import { createRequire } from "module"; const require = createRequire(import.meta.url);' dist/cli.js

    mkdir -p "$out/lib/bird-cli"
    cp -r dist "$out/lib/bird-cli/dist"

    # Ship runtime deps so Node can resolve e.g. `commander`.
    pnpm prune --prod --ignore-scripts

    # Drop common non-runtime payload to reduce closure size.
    rm -rf node_modules/.cache
    find node_modules -type d \( -name test -o -name tests -o -name "__tests__" -o -name docs -o -name ".github" \) -prune -exec rm -rf {} +
    find node_modules -type f \( -name "*.map" -o -name "*.md" -o -name "*.markdown" \) -delete

    cp -r node_modules "$out/lib/bird-cli/node_modules"

    makeWrapper ${runtimeNode}/bin/node "$out/bin/bird" \
      --set BIRD_VERSION "${finalAttrs.version}" \
      --set BIRD_GIT_SHA "${gitSha}" \
      --add-flags "$out/lib/bird-cli/dist/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Fast X/Twitter CLI using the undocumented GraphQL API";
    homepage = "https://github.com/p3psi-boo/bird-fork";
    license = lib.licenses.mit;
    mainProgram = "bird";
    platforms = runtimeNode.meta.platforms;
  };
})
