{
  lib,
  stdenv,
  generated,
  nodejs_22,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
  runCommandLocal,
}:

let
  sourceInfo = generated.dailyhot-api;
  version = sourceInfo.version;

  # Prepare source with pnpm-lock.yaml
  src = runCommandLocal "dailyhot-api-src" { } ''
    mkdir -p $out
    cp -r ${sourceInfo.src}/. $out/
    chmod -R u+w $out
    cp ${./pnpm-lock.yaml} $out/pnpm-lock.yaml
  '';

  pnpmDeps = fetchPnpmDeps {
    pname = "dailyhot-api";
    inherit version src;
    pnpm = pnpm_10;
    fetcherVersion = 1;
    hash = "sha256-miXYbAi+8mTsdigirC7D/RlHgFbv5DjbfM8lq38AGio=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dailyhot-api";
  inherit version src;

  nativeBuildInputs = [
    nodejs_22
    pnpmConfigHook
    pnpm_10
    makeWrapper
  ];

  inherit pnpmDeps;

  configurePhase = ''
    runHook preConfigure
    echo "supportedArchitectures.os=[\"${stdenv.hostPlatform.parsed.kernel.name}\"]" >> .npmrc
    echo "supportedArchitectures.cpu=[\"${stdenv.hostPlatform.parsed.cpu.name}\"]" >> .npmrc
    echo "auto-install-peers=true" >> .npmrc
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    pnpm install --frozen-lockfile --offline --ignore-scripts
    pnpm run build
    pnpm prune --production
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/dailyhot-api"
    install -d "$appDir" "$out/bin"

    cp -r dist "$appDir/"
    cp -r public "$appDir/"
    cp -r node_modules "$appDir/"
    cp package.json "$appDir/"

    # Copy default .env config with file logging disabled (nix store is read-only)
    if [ -f .env.example ]; then
      cp .env.example "$appDir/.env"
      sed -i 's/USE_LOG_FILE=true/USE_LOG_FILE=false/' "$appDir/.env"
    fi

    makeWrapper ${nodejs_22}/bin/node "$out/bin/dailyhot-api" \
      --set NODE_ENV docker \
      --add-flags "$appDir/dist/index.js" \
      --chdir "$appDir"

    runHook postInstall
  '';

  meta = with lib; {
    description = "今日热榜 API - An aggregated trending/hot data API";
    homepage = "https://github.com/imsyy/DailyHotApi";
    license = licenses.mit;
    mainProgram = "dailyhot-api";
    platforms = platforms.unix;
    maintainers = [ ];
  };
})
