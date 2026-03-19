{
  lib,
  buildRustPackage,
  fetchFromGitHub,
}:

let
  rustOptimized = import ../_lib/rust-optimized.nix;
in
buildRustPackage (
  rec {
    pname = "ut";
    version = "unstable";

    src = fetchFromGitHub {
      owner = "ksdme";
      repo = "ut";
      rev = "main";
      hash = "sha256-Bq8yow674GdChv9AGgmVZQ34+hyJdRq3G0jvIRJVNM4=";
    };

    cargoHash = "sha256-86XzsjDExg8SkFk5Bb8HeRiABCVd1FXQyX6xSsPsKHw=";

    doCheck = false;

    meta = with lib; {
      description = "A Rust based utility toolbox for developers";
      homepage = "https://github.com/ksdme/ut";
      license = licenses.mit; # Confirmed from web_fetch output
      maintainers = with maintainers; [ ];
    };
  }
  // rustOptimized.rustOptimizedEnv
)
