{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  cmake,
  go,
  perl,
  nasm,
  gitMinimal,
}:

let
  sourceInfo = generated.trusttunnel;
in
rustPlatform.buildRustPackage {
  pname = "trusttunnel";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
    cmake
    go
    perl
    nasm
    rustPlatform.bindgenHook
    gitMinimal
  ];

  cargoBuildFlags = [
    "-p"
    "trusttunnel_endpoint"
    "-p"
    "trusttunnel_endpoint_tools"
  ];

  cargoInstallFlags = [
    "-p"
    "trusttunnel_endpoint"
    "-p"
    "trusttunnel_endpoint_tools"
  ];

  doCheck = false;

  meta = with lib; {
    description = "Modern, fast and obfuscated VPN protocol endpoint";
    homepage = "https://github.com/TrustTunnel/TrustTunnel";
    license = licenses.asl20;
    mainProgram = "trusttunnel_endpoint";
    platforms = platforms.unix;
  };
}
