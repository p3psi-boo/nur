{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.wxmp_searxng;
in
buildGoModule {
  pname = "wxmp-searxng";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;
  vendorHash = lib.fakeHash;

  subPackages = [ "cmd/server" ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    mv "$out/bin/server" "$out/bin/wxmp-searxng"
  '';

  meta = {
    description = "Sogou Weixin JSON search engine for SearXNG";
    homepage = "https://github.com/p3psi-boo/wxmp_searxng";
    license = lib.licenses.mit;
    mainProgram = "wxmp-searxng";
    platforms = lib.platforms.unix;
  };
}
