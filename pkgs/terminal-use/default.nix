{
  lib,
  rustPlatform,
  generated,
}:

let
  sourceInfo = generated.terminal-use;
in
rustPlatform.buildRustPackage {
  pname = "terminal-use";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  doCheck = false;

  meta = with lib; {
    description = "Headless virtual terminal for AI agents — tmux for your coding agent";
    homepage = "https://github.com/flipbit03/terminal-use";
    changelog = "https://github.com/flipbit03/terminal-use/releases/tag/${sourceInfo.version}";
    license = licenses.mit;
    mainProgram = "tu";
    platforms = platforms.unix;
  };
}
