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

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
  ];

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
