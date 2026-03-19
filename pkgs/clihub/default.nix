{
  buildGoModule,
  fetchFromGitHub,
  generated ? null,
  lib,
}:

let
  sourceInfo =
    if generated != null && generated ? clihub then
      generated.clihub
    else
      rec {
        version = "v0.0.7";
        src = fetchFromGitHub {
          owner = "thellimist";
          repo = "clihub";
          rev = version;
          hash = "sha256-fonfxfAoQHUqbk27wHi7DpIo9pfgoxtdTGmp/stDmLU=";
        };
      };
in
buildGoModule {
  pname = "clihub";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = "sha256-4s1d8h2Wnqpar9M4vPZB55Y80v0x45QHG70JZFT3rPY=";

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${sourceInfo.version}"
  ];

  doCheck = false;

  meta = {
    description = "Turn any MCP server into a compiled CLI binary";
    homepage = "https://github.com/thellimist/clihub";
    changelog = "https://github.com/thellimist/clihub/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "clihub";
  };
}
