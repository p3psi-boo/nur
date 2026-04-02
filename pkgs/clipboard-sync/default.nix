{
  lib,
  rustPlatform,
  generated,
  libxcb,
}:

let
  sourceInfo = generated.clipboard-sync;
in
rustPlatform.buildRustPackage {
  pname = "clipboard-sync";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  cargoLock.lockFile = sourceInfo.src + "/Cargo.lock";

  buildInputs = [
    libxcb
  ];

  meta = with lib; {
    description = "Synchronizes the clipboard across multiple X11 and wayland instances";
    homepage = "https://github.com/dnut/clipboard-sync";
    license = with licenses; [ mit asl20 ];
    platforms = platforms.linux;
    mainProgram = "clipboard-sync";
  };
}
