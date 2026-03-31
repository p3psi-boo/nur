{
  lib,
  buildRustPackage,
  generated,
  nurLib,
}:

let
  sourceInfo = generated.ut;
in
buildRustPackage (finalAttrs: (
  {
    pname = "ut";
    version = "0-unstable-${sourceInfo.date}";

    src = sourceInfo.src;

    cargoHash = "sha256-NsMtTEI5T7eRIFvmOpOpgIWAvmIVD/ojowarLyKiSCM=";

    doCheck = false;

    meta = with lib; {
      description = "A Rust based utility toolbox for developers";
      homepage = "https://github.com/ksdme/ut";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
      mainProgram = "ut";
    };
  }
  // nurLib.rustOptimizedEnv
))
