{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.web-search;
in
buildGoModule (finalAttrs: {
  pname = "web-search";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-VfJwNVFAxsgOA1B84ex9IAu3yX+isoQ3DFscXk3Z3Nc=";

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  buildFlags = [ "-gcflags=all=-l=4" ];

  postInstall = ''
    install -Dm644 config.example.toml "$out/share/doc/${finalAttrs.pname}/config.example.toml"
  '';

  meta = with lib; {
    description = "Keyword and semantic web search CLI and server";
    homepage = "https://github.com/p3psi-boo/web-search";
    license = licenses.unfree;
    mainProgram = "web-search";
  };
})
