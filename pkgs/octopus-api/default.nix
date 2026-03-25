{
  lib,
  stdenvNoCC,
  buildGoModule,
  generated,
  go_1_24,
  nodejs_22,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
}:

let
  sourceInfo = generated.octopus-api;
  pnpm = pnpm_10;
  frontend = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "octopus-api-ui";
    version = lib.removePrefix "v" sourceInfo.version;

    src = sourceInfo.src;
    sourceRoot = "${sourceInfo.src.name}/web";

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname version src sourceRoot;
      pnpm = pnpm;
      fetcherVersion = 3;
      hash = "sha256-5eNPFSNplTzv73RcnZHKl/PR7BKJ0MhJKBPUMzRqy8Y=";
    };

    nativeBuildInputs = [
      nodejs_22
      pnpm
      pnpmConfigHook
    ];

    buildPhase = ''
      runHook preBuild
      HOME="$TMPDIR"
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r out/. "$out/"
      runHook postInstall
    '';
  });
in
(buildGoModule.override { go = go_1_24; }) {
  pname = "octopus-api";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  env.CGO_ENABLED = "0";

  preBuild = ''
    rm -rf static/out
    mkdir -p static/out
    cp -r ${frontend}/. static/out/
  '';

  vendorHash = "sha256-0GLn/CfYu1flQpYmR9IoaYd6pTWwqqMLS3x1DsqRres=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/bestruirui/octopus/internal/conf.Version=${sourceInfo.version}"
  ];

  doCheck = false;

  postInstall = ''
    mkdir -p "$out/libexec/octopus-api"
    mv "$out/bin/octopus" "$out/libexec/octopus-api/octopus"
    ln -s "$out/libexec/octopus-api/octopus" "$out/bin/octopus-api"
  '';

  meta = {
    description = "LLM API aggregation and load balancing service for individuals";
    homepage = "https://github.com/bestruirui/octopus";
    changelog = "https://github.com/bestruirui/octopus/releases/tag/${sourceInfo.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "octopus-api";
    platforms = lib.platforms.unix;
  };
}
