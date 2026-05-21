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

  # Prepare frontend source (upstream v1.1.2 includes its own pnpm-lock.yaml)
  frontendSrc = runCommandLocal "bichon-frontend-src" { } ''
    mkdir -p $out
    cp -r ${sourceInfo.src}/web/. $out/
    chmod -R u+w $out
  '';

  # Prefetched pnpm dependencies for the frontend
  pnpmDeps = fetchPnpmDeps {
    pname = "bichon-frontend";
    inherit version;
    src = frontendSrc;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-Ao05wTo170b/K9JtuoIoF0UHwE8tmWkQHjDR2TKUi7I=";
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
      "outlook-pst-1.1.0" = "sha256-F20It1IJvWEQZhb6RdMirj4PHpMn4lM9NhbnlEgyxtA=";
      "async-imap-0.11.2" = "sha256-gBmweTd8QWl3ebuYgQzu2vEMHtegA05SsbtQD3n2wjs=";
    };
  };

  # Patch build.rs to not require git (no .git in fetched source)
  # Also downgrade sysinfo to a version compatible with rustc 1.94
  postPatch = ''
    substituteInPlace crates/server/build.rs \
      --replace-fail 'Command::new("git")' 'Command::new("echo")' \
      --replace-fail '.args(&["rev-parse", "--short", "HEAD"])' '.arg("${version}")'

    substituteInPlace Cargo.lock \
      --replace-fail 'name = "sysinfo"' 'name = "sysinfo__patched"' \
      --replace-fail 'version = "0.39.1"' 'version = "0.38.4"' \
      --replace-fail 'checksum = "a4deba334e1190ba7cb498327affa11e5ece10d26a30ab2f27fcf09504b8d8b6"' 'checksum = "92ab6a2f8bfe508deb3c6406578252e491d299cbbf3bc0529ecc3313aee4a52f"'

    # Undo the temporary name change
    substituteInPlace Cargo.lock \
      --replace-fail 'name = "sysinfo__patched"' 'name = "sysinfo"'
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
