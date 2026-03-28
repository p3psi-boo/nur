{
  lib,
  buildRustPackage,
  fetchFromGitHub,
}:

let
  rustOptimized = import ../_lib/rust-optimized.nix;
in
buildRustPackage (finalAttrs: (
  {
    pname = "codegraph";
    version = "1.0.0";

    src = fetchFromGitHub {
      owner = "Jakedismo";
      repo = "codegraph-rust";
      rev = "ff1c43f3c48536d6e238cf7f86f780dd63ef5347";
      hash = "sha256-rCROSFq7wWNbKMrwjS7T8YfSr7tAvoiijeX/sMFSymw=";
    };

    cargoHash = "sha256-vMtc1AOtjoaV6WSoRko3Q6EfeePz5zDVqH7ftgFIqy4=";

    doCheck = false;

    meta = with lib; {
      description = "A code graph tool for understanding code structure and relationships";
      homepage = "https://github.com/Jakedismo/codegraph-rust";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
      platforms = platforms.linux ++ platforms.darwin;
      mainProgram = "codegraph";
    };
  }
  // rustOptimized.rustOptimizedEnv
))
