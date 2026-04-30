{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  protobuf,
  openssl,
}:

let
  sourceInfo = generated.wtfps;
in
rustPlatform.buildRustPackage {
  pname = "wtfps";
  version = "0-unstable-${sourceInfo.date}";

  inherit (sourceInfo) src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
    protobuf
  ];

  buildInputs = [
    openssl
  ];

  SQLX_OFFLINE = "true";

  doCheck = false;

  meta = {
    description = "Extract Wi-Fi positioning data from Apple's Wi-Fi Positioning System";
    homepage = "https://codeberg.org/joelkoen/wtfps";
    license = lib.licenses.gpl3Only;
    mainProgram = "wtfps";
    platforms = lib.platforms.linux;
  };
}
