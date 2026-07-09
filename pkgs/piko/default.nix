{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.piko;
in
buildGoModule {
  pname = "piko";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = "sha256-IuH/IKLRQE6eQarXQrgUz2Obpy1Zn5hxtx44eUXGM+Y=";

  subPackages = [ "cmd/piko" ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Small segmented downloader for CLI and Go programs";
    homepage = "https://github.com/UruhaLushia/piko";
    license = lib.licenses.gpl3Only;
    mainProgram = "piko";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
