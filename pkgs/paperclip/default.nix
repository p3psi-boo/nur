{
  lib,
  stdenv,
  generated,
  nodejs_22,
  nodejs-slim_22,
  pnpm_9,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
  postgresql,
  git,
}:

let
  pnpm = pnpm_9;
  runtimeNode = nodejs-slim_22;
  sourceInfo = generated.paperclip;
  version = "0-unstable-${sourceInfo.date}";

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
    }.${arch} or arch;

  setPnpmArch = ''
    echo "supportedArchitectures.os=[\"${npmOs}\"]" >> .npmrc
    echo "supportedArchitectures.cpu=[\"${npmCpu}\"]" >> .npmrc
    echo "auto-install-peers=true" >> .npmrc
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "paperclip";
  inherit version;

  src = sourceInfo.src;

  pnpmDeps = (fetchPnpmDeps.override { inherit pnpm; }) {
    inherit (finalAttrs) pname version src;
    hash = "sha256-b35YfaE+5L/Sf1OScs7TKFwXSB3EE/zTH+l03dHT2Vc=";
    fetcherVersion = 3;
    prePnpmInstall = setPnpmArch;
  };

  prePnpmInstall = setPnpmArch;

  nativeBuildInputs = [
    nodejs_22
    pnpm
    (pnpmConfigHook.override { inherit pnpm; })
    makeWrapper
  ];

  buildInputs = [
    postgresql
  ];

  buildPhase = ''
    runHook preBuild

    # Build all packages in the workspace (server/ui/cli + internal deps)
    pnpm run build

    # Keep only runtime dependencies
    pnpm prune --prod --ignore-scripts

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/paperclip" "$out/bin"

    # Keep workspace layout intact to preserve pnpm symlink graph
    cp -r . "$out/lib/paperclip/"

    # Remove obvious non-runtime payload to reduce closure size
    rm -rf "$out/lib/paperclip/.git" "$out/lib/paperclip/.github" 2>/dev/null || true
    rm -rf "$out/lib/paperclip/doc" "$out/lib/paperclip/docs" "$out/lib/paperclip/evals" "$out/lib/paperclip/tests" 2>/dev/null || true
    rm -rf "$out/lib/paperclip/.agents" "$out/lib/paperclip/.claude" "$out/lib/paperclip/releases" "$out/lib/paperclip/report" 2>/dev/null || true
    rm -rf "$out/lib/paperclip/cli/src" "$out/lib/paperclip/server/src" "$out/lib/paperclip/ui/src" 2>/dev/null || true
    find "$out/lib/paperclip" -type f \( -name "*.map" -o -name "*.md" -o -name "*.markdown" \) -delete

    # prune may leave dead top-level links to removed dev deps
    find "$out/lib/paperclip" -xtype l -delete

    # CLI bundle imports dependencies from bundled workspace code, but some of
    # them are not declared in cli/package.json. Expose them for runtime module
    # resolution.
    ln -sf ../../packages/shared/node_modules/zod "$out/lib/paperclip/cli/node_modules/zod"
    ln -sf ../../packages/db/node_modules/postgres "$out/lib/paperclip/cli/node_modules/postgres"

    # Create wrapper script for the CLI
    cat > "$out/bin/paperclipai" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

export PAPERCLIP_HOME="''${PAPERCLIP_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/paperclip}"
mkdir -p "$PAPERCLIP_HOME"

# Create data directory for embedded PostgreSQL
export PAPERCLIP_DATA_DIR="''${PAPERCLIP_DATA_DIR:-$PAPERCLIP_HOME/data}"
mkdir -p "$PAPERCLIP_DATA_DIR"

cd "@out@/lib/paperclip"

# Run the CLI
exec @node@/bin/node "@out@/lib/paperclip/cli/dist/index.js" "$@"
EOF

    substituteInPlace "$out/bin/paperclipai" \
      --subst-var-by out "$out" \
      --subst-var-by node "${runtimeNode}"

    chmod +x "$out/bin/paperclipai"

    runHook postInstall
  '';

  # PostgreSQL and git are needed at runtime
  # Use explicit binary outputs to avoid dragging dev outputs (and clang/llvm)
  propagatedBuildInputs = [
    postgresql.out
    git
  ];

  passthru = {
    inherit sourceInfo;
  };

  meta = {
    description = "Open-source orchestration for zero-human companies";
    homepage = "https://github.com/paperclipai/paperclip";
    license = lib.licenses.mit;
    mainProgram = "paperclipai";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
