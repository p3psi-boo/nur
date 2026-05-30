{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  oniguruma,
}:

let
  sourceInfo = generated.leaf;
in
rustPlatform.buildRustPackage {
  pname = "leaf";
  version = sourceInfo.version;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    oniguruma
  ];

  doCheck = false;

  meta = {
    description = "Terminal Markdown previewer — GUI-like experience";
    homepage = "https://github.com/rivolink/leaf";
    changelog = "https://github.com/rivolink/leaf/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "leaf";
    platforms = lib.platforms.unix;
  };
}
