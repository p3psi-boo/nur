{
  lib,
  buildDartApplication,
  generated,
}:

let
  sourceInfo = generated.fdb;
in
buildDartApplication {
  pname = "fdb";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  pubspecLock = lib.importJSON ./pubspec.lock.json;

  meta = {
    description = "Flutter Debug Bridge - CLI for AI agents to interact with running Flutter apps on device";
    homepage = "https://github.com/andrzejchm/fdb";
    license = lib.licenses.mit;
    mainProgram = "fdb";
    platforms = [ "aarch64-darwin" ];
  };
}
