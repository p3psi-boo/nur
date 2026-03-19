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
  version = sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = "sha256-VfJwNVFAxsgOA1B84ex9IAu3yX+isoQ3DFscXk3Z3Nc=";

  env.CGO_ENABLED = "0";

  subPackages = [
    "cmd/web-search"
    "cmd/web-search-server"
  ];

  ldflags = [
    "-s"
    "-w"
  ];

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
