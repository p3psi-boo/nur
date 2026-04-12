# fusion - A lightweight, self-hosted friendly RSS reader
# https://github.com/p3psi-boo/fusion
{
  lib
, stdenv
, buildGoModule
, generated
, nodejs_22
, pnpm_10
, fetchPnpmDeps
, pnpmConfigHook
, go_1_26
, runCommandLocal
}:

let
  sourceInfo = generated.fusion;
  version = "0-unstable-${sourceInfo.date}";

  # Prepare frontend source with pnpm-lock.yaml
  frontendSrc = runCommandLocal "fusion-frontend-src" { } ''
    mkdir -p $out
    cp -r ${sourceInfo.src}/frontend/. $out/
    chmod -R u+w $out
    cp ${./pnpm-lock.yaml} $out/pnpm-lock.yaml
  '';

  # Prefetched pnpm dependencies for the frontend
  pnpmDeps = fetchPnpmDeps {
    pname = "fusion-frontend";
    inherit version;
    src = frontendSrc;
    pnpm = pnpm_10;
    fetcherVersion = 1;
    hash = "sha256-CcJ6NNZfKAj6V9nfI9RK9xQKrjI7O4oeQ/t3do07ovA=";
    NODE_ENV = "production";
  };

  # Built frontend dist directory
  frontendDist = stdenv.mkDerivation {
    pname = "fusion-frontend-dist";
    inherit version;
    src = frontendSrc;

    nativeBuildInputs = [
      nodejs_22
      pnpmConfigHook
      pnpm_10
    ];

    inherit pnpmDeps;

    NODE_ENV = "production";
    VITE_FUSION_VERSION = version;

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
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/. $out/
      runHook postInstall
    '';
  };
in

buildGoModule {
  pname = "fusion";
  inherit version;
  inherit (sourceInfo) src;

  modRoot = "backend";
  subPackages = [ "cmd/fusion" ];

  vendorHash = "sha256-I3LxZHB4lhfLEMpX1nVOjoLd59y602TEpBke3W8gYhE=";
  doCheck = false;
  go = go_1_26;

  env.CGO_ENABLED = "0";

  preBuild = ''
    # Copy pre-built frontend dist into backend embed directory
    # Note: modRoot="backend", so we're already in the backend directory
    mkdir -p internal/web/dist
    cp -r ${frontendDist}/. internal/web/dist/
  '';

  ldflags = [
    "-s"
    "-w"
    "-extldflags '-static'"
    "-X main.version=${version}"
  ];

  meta = {
    description = "A lightweight, self-hosted friendly RSS reader";
    homepage = "https://github.com/p3psi-boo/fusion";
    license = lib.licenses.mit;
    mainProgram = "fusion";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = [ ];
  };
}
