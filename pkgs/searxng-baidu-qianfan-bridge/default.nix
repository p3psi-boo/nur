{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.searxng-baidu-qianfan-bridge;
in
buildGoModule {
  pname = "searxng-baidu-qianfan-bridge";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = null;

  subPackages = [ "." ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Baidu Qianfan web search bridge for SearXNG";
    homepage = "https://github.com/p3psi-boo/searxng-baidu-qianfan-bridge";
    changelog = "https://github.com/p3psi-boo/searxng-baidu-qianfan-bridge/commits/main/";
    license = lib.licenses.unfree;
    mainProgram = "searxng-baidu-qianfan-bridge";
    platforms = lib.platforms.unix;
  };
}
