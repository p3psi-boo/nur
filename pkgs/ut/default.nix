{
  lib,
  buildRustPackage,
  generated,
}:

let
  rustOptimized = import ../_lib/rust-optimized.nix;
  sourceInfo = generated.ut;
in
buildRustPackage (
  rec {
    pname = "ut";
    version = "unstable-${sourceInfo.date}";

    src = sourceInfo.src;

    cargoHash = "sha256-NsMtTEI5T7eRIFvmOpOpgIWAvmIVD/ojowarLyKiSCM=";

    doCheck = false;

    meta = with lib; {
      description = "A Rust based utility toolbox for developers";
      homepage = "https://github.com/ksdme/ut";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
    };
  }
  // rustOptimized.rustOptimizedEnv
)
