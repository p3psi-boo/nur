{
  lib,
  buildGoModule,
  makeWrapper,
  wireguard-tools,
  iproute2,
  generated,
}:
let
  sourceInfo = generated.wgrest;
in
buildGoModule rec {
  pname = "wgrest";
  version = "0-unstable-${sourceInfo.date}";
  inherit (sourceInfo) src;
  vendorHash = "sha256-mN8BQighSikAq5x8zNxgIU4V3E3JzKWJgzrlI4aX180=";
  subPackages = [ "cmd/wgrest-server" ];
  nativeBuildInputs = [ makeWrapper ];
  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
    "-X=main.appVersion=${version}"
  ];
  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';
  postInstall = ''
    mv "$out/bin/wgrest-server" "$out/bin/wgrest"
    wrapProgram "$out/bin/wgrest" --prefix PATH : ${
      lib.makeBinPath [
        wireguard-tools
        iproute2
      ]
    }
  '';
  meta = {
    description = "REST API for WireGuard interfaces and peers";
    homepage = "https://github.com/suquant/wgrest";
    license = lib.licenses.asl20;
    mainProgram = "wgrest";
    platforms = lib.platforms.linux;
  };
}
