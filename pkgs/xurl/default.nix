{
  lib,
  rustPlatform,
  generated,
  pkg-config,
}:

let
  sourceInfo = generated.xurl;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "xurl";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  cargoBuildFlags = [
    "-p"
    "xurl-cli"
  ];

  cargoTestFlags = finalAttrs.cargoBuildFlags;

  doCheck = false;

  meta = {
    description = "Client for AI Agents URLs — read, query, discover, and write conversations through a unified agents:// URI scheme";
    homepage = "https://github.com/Xuanwo/xurl";
    changelog = "https://github.com/Xuanwo/xurl/commits/${sourceInfo.version}";
    license = lib.licenses.asl20;
    mainProgram = "xurl";
    platforms = lib.platforms.unix;
  };
})
