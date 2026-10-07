{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.firefox-vpn-client;
in
buildGoModule {
  pname = "firefox-vpn-client";
  version = "0-unstable-${sourceInfo.date}";

  inherit (sourceInfo) src;

  vendorHash = "sha256-jP6xweR5Xz5SY5dl8bbVXeGKqog1q83qNVT4p5LWzgw=";

  subPackages = [ "cmd/proxy-demo" ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    mv "$out/bin/proxy-demo" "$out/bin/firefox-vpn-client"
  '';

  meta = {
    description = "Firefox VPN client with a local SOCKS5 proxy";
    homepage = "https://github.com/UjuiUjuMandan/firefox-vpn-client";
    changelog = "https://github.com/UjuiUjuMandan/firefox-vpn-client/commits/master/";
    license = lib.licenses.unfree;
    mainProgram = "firefox-vpn-client";
    platforms = lib.platforms.unix;
  };
}
