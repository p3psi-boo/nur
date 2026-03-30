{
  lib,
  stdenv,
  generated ? null,
  fetchFromGitHub,
  runCommand,
  nodejs_22,
  nodejs-slim_22,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:

let
  pnpm = pnpm_10;
  runtimeNode = nodejs-slim_22;
  sourceInfo =
    if generated != null && generated ? openalice then
      generated.openalice
    else
      {
        version = "0.9.0-beta.8";
        src = fetchFromGitHub {
          owner = "TraderAlice";
          repo = "OpenAlice";
          rev = "06345e11c34c8a8a56c7e6b5f03bd04bad46ff2b";
          hash = "sha256-EXb4iex3yK2nJSDsrJO+IgzfMHR5HD62xUNeLKfpeNQ=";
        };
      };
  version =
    if sourceInfo ? date then
      "0-unstable-${sourceInfo.date}"
    else
      lib.removePrefix "v" sourceInfo.version;

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

  setPnpmArch = ''
    echo "supportedArchitectures.os=[\"${npmOs}\"]" >> .npmrc
    echo "supportedArchitectures.cpu=[\"${npmCpu}\"]" >> .npmrc
    echo "auto-install-peers=true" >> .npmrc
  '';

  srcWithNpmrc = runCommand "openalice-src-${version}" { } ''
    cp -r ${sourceInfo.src} "$out"
    chmod -R u+w "$out"

    # Build @traderalice/ibkr with tsup instead of raw tsc so emitted ESM is
    # directly runnable under Node without extensionless relative imports.
    sed -i 's|"build": "rm -rf dist && tsc"|"build": "tsup"|' "$out/packages/ibkr/package.json"
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "openalice";
  inherit version;

  src = srcWithNpmrc;

  pnpmDeps = (fetchPnpmDeps.override { inherit pnpm; }) {
    inherit (finalAttrs) pname version src;
    hash = "sha256-jhH1Z+F/ZP5RU7xP+9p78AMVO5Xiv+vTq13ORFg2BCo=";
    fetcherVersion = 1;
    prePnpmInstall = setPnpmArch;
  };

  prePnpmInstall = setPnpmArch;

  nativeBuildInputs = [
    nodejs_22
    pnpm
    (pnpmConfigHook.override { inherit pnpm; })
    makeWrapper
  ];

  CI = "true";

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/openalice/app" "$out/bin"

    cp -r dist "$out/lib/openalice/app/dist"
    cp -r default "$out/lib/openalice/app/default"
    cp -r packages "$out/lib/openalice/app/packages"
    cp -r ui "$out/lib/openalice/app/ui"
    cp -r node_modules "$out/lib/openalice/app/node_modules"
    cp package.json pnpm-workspace.yaml "$out/lib/openalice/app/"

    cat > "$out/bin/openalice" <<'EOF'
#!${stdenv.shell}
set -euo pipefail

state_dir="''${OPENALICE_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/openalice}"
mkdir -p "$state_dir" "$state_dir/data"

ln -sfn "${placeholder "out"}/lib/openalice/app/dist" "$state_dir/dist"
ln -sfn "${placeholder "out"}/lib/openalice/app/default" "$state_dir/default"
ln -sfn "${placeholder "out"}/lib/openalice/app/packages" "$state_dir/packages"
ln -sfn "${placeholder "out"}/lib/openalice/app/ui" "$state_dir/ui"
ln -sfn "${placeholder "out"}/lib/openalice/app/node_modules" "$state_dir/node_modules"
ln -sfn "${placeholder "out"}/lib/openalice/app/package.json" "$state_dir/package.json"
ln -sfn "${placeholder "out"}/lib/openalice/app/pnpm-workspace.yaml" "$state_dir/pnpm-workspace.yaml"

cd "$state_dir"
exec ${runtimeNode}/bin/node "$state_dir/dist/main.js" "$@"
EOF

    chmod +x "$out/bin/openalice"

    runHook postInstall
  '';

  meta = {
    description = "File-driven AI trading agent engine for crypto and securities markets";
    homepage = "https://github.com/TraderAlice/OpenAlice";
    license = lib.licenses.agpl3Only;
    mainProgram = "openalice";
    platforms = runtimeNode.meta.platforms;
  };
})
