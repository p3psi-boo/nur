{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.oura-cli;
in
buildGoModule {
  pname = "oura-cli";
  version = sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = null;

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
  };

  ldflags = [ "-s" "-w" ];

  buildFlags = [ "-gcflags=all=-l=4" ];

  subPackages = [ "." ];

  postInstall = ''
    mv $out/bin/oura $out/bin/oura-cli
  '';

  meta = {
    description = "Oura Ring CLI - OAuth2 authenticated CLI for Oura API";
    homepage = "https://github.com/p3psi-boo/oura-cli";
    license = lib.licenses.mit;
    mainProgram = "oura-cli";
  };
}
