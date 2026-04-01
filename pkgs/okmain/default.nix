{
  lib,
  rustPlatform,
  generated,
}:

let
  sourceInfo = generated.okmain;
in
rustPlatform.buildRustPackage {
  pname = "okmain";
  version = sourceInfo.date;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = "${sourceInfo.src}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };

  buildAndTestSubdir = "crates/okmain";

  # Build debug binaries with image support
  buildFeatures = [ "_debug" "image" ];

  # Runtime performance optimizations
  CARGO_BUILD_INCREMENTAL = "false";
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";
  CARGO_PROFILE_RELEASE_LTO = "fat";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_PANIC = "abort";

  postInstall = ''
    # Rename debug binaries to more useful names
    for bin in $out/bin/debug_*; do
      if [ -f "$bin" ]; then
        newname=$(basename "$bin" | sed 's/debug_//')
        mv "$bin" "$out/bin/okmain-$newname"
      fi
    done
  '';

  meta = {
    description = "Find main colors of an image, making sure they look good (debug tools)";
    homepage = "https://github.com/si14/okmain";
    changelog = "https://github.com/si14/okmain/commits/main";
    license = lib.licenses.asl20;
    mainProgram = "okmain-colors";
    platforms = lib.platforms.all;
  };
}
