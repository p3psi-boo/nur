{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.searxng-doubao-bridge;
in
buildGoModule {
  pname = "searxng-doubao-bridge";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = null;

  subPackages = [ "cmd/doubao-search" ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    install -Dm644 searxng-settings.yml \
      "$out/share/doc/searxng-doubao-bridge/searxng-settings.yml"
  '';

  meta = {
    description = "Volcengine Doubao web search bridge for SearXNG";
    homepage = "https://github.com/p3psi-boo/searxng-doubao-bridge";
    changelog = "https://github.com/p3psi-boo/searxng-doubao-bridge/commits/main/";
    license = lib.licenses.mit;
    mainProgram = "doubao-search";
    platforms = lib.platforms.unix;
  };
}
