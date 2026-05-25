{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  openssl,
}:

let
  sourceInfo = generated.commandcode2api;
in
rustPlatform.buildRustPackage {
  pname = "commandcode2api";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  doCheck = false;

  meta = {
    description = "OpenAI-compatible API proxy for Command Code";
    homepage = "https://github.com/p3psi-boo/commandcode2api";
    license = lib.licenses.mit;
    mainProgram = "commandcode2api";
    platforms = lib.platforms.linux;
  };
}
