{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "komari-monitor-rs";
  version = "0-unstable-2026-04-17";

  src = fetchFromGitHub {
    owner = "p3psi-boo";
    repo = "komari-monitor-rs";
    rev = "5da85d874ab853e5b153e9626a35718747f1b9d8";
    hash = "sha256-7v0UUEDpo1K9Zqp6076JINCQDC334zG5i7pfHfnMtng=";
  };

  cargoHash = "sha256-vypPc5d5fZfYdRTm0l71bQFN1TFFjnTRdwNmu7ly4Cc=";

  buildFeatures = [ "ureq-support" ];

  doCheck = false;

  meta = {
    description = "Komari Monitor Agent in Rust";
    homepage = "https://github.com/p3psi-boo/komari-monitor-rs";
    license = lib.licenses.wtfpl;
    maintainers = [ ];
    platforms = lib.platforms.linux;
    mainProgram = "komari-monitor-rs";
  };
}
