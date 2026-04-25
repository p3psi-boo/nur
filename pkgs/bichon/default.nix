{
  lib,
  stdenv,
  rustPlatform,
  generated,
  nodejs_22,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  runCommandLocal,
  pkg-config,
  openssl,
}:

let
  sourceInfo = generated.bichon;
  version = sourceInfo.version;

  # Prepare frontend source with pnpm-lock.yaml
  frontendSrc = runCommandLocal "bichon-frontend-src" { } ''
    mkdir -p $out
    cp -r ${sourceInfo.src}/web/. $out/
    chmod -R u+w $out
    cp ${./pnpm-lock.yaml} $out/pnpm-lock.yaml
  '';

  # Prefetched pnpm dependencies for the frontend
  pnpmDeps = fetchPnpmDeps {
    pname = "bichon-frontend";
    inherit version;
    src = frontendSrc;
    pnpm = pnpm_10;
    fetcherVersion = 1;
    hash = "sha256-hc+GtZOzP47Joyak6KhmifG7jV4kpVG5+zCMKe7Emuk=";
    NODE_ENV = "production";
  };

  # Built frontend dist directory
  frontendDist = stdenv.mkDerivation {
    pname = "bichon-frontend-dist";
    inherit version;
    src = frontendSrc;

    nativeBuildInputs = [
      nodejs_22
      pnpmConfigHook
      pnpm_10
    ];

    inherit pnpmDeps;

    NODE_ENV = "production";

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
rustPlatform.buildRustPackage {
  pname = "bichon";
  inherit version;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
    outputHashes = {
      "outlook-pst-1.1.0" = "sha256-yQ+yk+Rjaxz7SoC/7T4Jy7R+IJmuTLZrcRyThtZhIys=";
    };
  };

  # Patch build.rs to not require git (no .git in fetched source)
  postPatch = ''
    substituteInPlace build.rs \
      --replace-fail 'Command::new("git")' 'Command::new("echo")' \
      --replace-fail '.args(&["rev-parse", "--short", "HEAD"])' '.arg("${version}")'
  '';

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  preBuild = ''
    # Copy pre-built frontend dist into the web/dist directory for rust-embed
    rm -rf web/dist
    mkdir -p web/dist
    cp -r ${frontendDist}/. web/dist/
  '';

  doCheck = false;

  meta = with lib; {
    description = "A lightweight, high-performance Rust email archiver with WebUI";
    homepage = "https://github.com/rustmailer/bichon";
    license = licenses.agpl3Only;
    mainProgram = "bichon";
    platforms = platforms.unix;
  };
}
