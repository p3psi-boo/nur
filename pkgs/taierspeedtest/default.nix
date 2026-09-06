{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.taierspeedtest;
  version = lib.removePrefix "v" sourceInfo.version;
in
buildGoModule {
  pname = "taierspeedtest";
  inherit version;

  src = sourceInfo.src;

  vendorHash = "sha256-TNlgvlNkILovwyNQ8UQVVraH8Jmnzenrt8JY6bsFNZg=";

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${version}"
  ];

  meta = {
    description = "全球网测 / 泰尔测速 Linux 客户端";
    homepage = "https://github.com/MiaM1ku/taierspeedtest";
    changelog = "https://github.com/MiaM1ku/taierspeedtest/releases/tag/v${version}";
    # Upstream does not declare a license.
    license = lib.licenses.unfree;
    mainProgram = "taierspeedtest";
    platforms = lib.platforms.linux;
  };
}
