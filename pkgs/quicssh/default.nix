{
  buildGoModule,
  generated,
  go_1_24,
  lib,
}:

let
  sourceInfo = generated.quicssh;
in
buildGoModule (finalAttrs: {
  pname = "quicssh";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = "sha256-0tSd26bEJ/dE+mLmbneOfAAlMwdndBJuUVGPmDs8Les=";

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";  # x86-64-v3 指令集优化
  };

  # 运行时性能优化
  ldflags = [
    "-s"
    "-w"
  ];

  # 启用激进内联优化
  buildFlags = [ "-gcflags=all=-l=4" ];

  go = go_1_24;

  postPatch = ''
    sed -i 's|golang.org/x/net/context|context|g' *.go
  '';

  subPackages = [ "." ];

  meta = {
    description = "SSH over QUIC";
    homepage = "https://github.com/moul/quicssh";
    downloadPage = "https://github.com/moul/quicssh/releases";
    changelog = "https://github.com/moul/quicssh/releases/tag/${sourceInfo.version}";
    license = lib.licenses.asl20;
    mainProgram = "quicssh";
  };
})
