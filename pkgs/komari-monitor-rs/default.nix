{
  generated,
  lib,
  rustPlatform,
}:

let
  sourceInfo = generated.komari-monitor-rs;
in
rustPlatform.buildRustPackage {
  pname = "komari-monitor-rs";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  cargoHash = "sha256-vypPc5d5fZfYdRTm0l71bQFN1TFFjnTRdwNmu7ly4Cc=";

  buildFeatures = [ "ureq-support" ];

  doCheck = false;

  meta = {
    description = "Komari Monitor Agent in Rust";
    homepage = "https://github.com/p3psi-boo/komari-monitor-rs";
    license = lib.licenses.wtfpl;
    maintainers = [ ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "komari-monitor-rs";
  };
}
