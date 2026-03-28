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
      let
        version = "v0.0.7";
      in
      {
        inherit version;
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

  # 运行时性能优化环境
  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";  # x86-64-v3 指令集优化
  };

  vendorHash = "sha256-4s1d8h2Wnqpar9M4vPZB55Y80v0x45QHG70JZFT3rPY=";

  # 运行时性能优化
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${sourceInfo.version}"
  ];

  # 启用激进内联优化
  buildFlags = [ "-gcflags=all=-l=4" ];

  doCheck = false;

  meta = {
    description = "Turn any MCP server into a compiled CLI binary";
    homepage = "https://github.com/thellimist/clihub";
    changelog = "https://github.com/thellimist/clihub/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "clihub";
  };
}
