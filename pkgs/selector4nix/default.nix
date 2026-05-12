{
  lib,
  rustPlatform,
  generated,
}:

let
  sourceInfo = generated.selector4nix;
in
rustPlatform.buildRustPackage {
  pname = "selector4nix";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  cargoLock.lockFile = sourceInfo.src + "/Cargo.lock";

  cargoBuildFlags = [
    "-p"
    "selector4nix"
  ];

  cargoInstallFlags = [
    "-p"
    "selector4nix"
  ];

  cargoTestFlags = [
    "-p"
    "selector4nix"
  ];

  meta = {
    description = "Nix substituter proxy with parallel cache queries and latency-aware selection";
    homepage = "https://github.com/starryreverie/selector4nix";
    license = lib.licenses.gpl3Plus;
    mainProgram = "selector4nix";
    platforms = lib.platforms.unix;
  };
}
