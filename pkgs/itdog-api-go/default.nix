{
  lib,
  buildGoModule,
  generated,
}:
let
  sourceInfo = generated.itdog-api-go;
in
buildGoModule {
  pname = "itdog-api-go";
  version = "0-unstable-${sourceInfo.date}";
  src = sourceInfo.src;

  vendorHash = "sha256-bou+cHCJ6996FmQPsZMChlIzLVs/u43xo4aiNOCihWs=";
  subPackages = [ "cmd/server" ];
  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
  ];

  # Include the HTTP API and upstream protocol regression suites as well as main.
  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';

  postInstall = ''
    mv "$out/bin/server" "$out/bin/itdog-api-go"
    install -Dm644 README.md "$out/share/doc/itdog-api-go/README.md"
  '';

  meta = {
    description = "Go HTTP API for ITDOG network diagnostics";
    homepage = "https://github.com/p3psi-boo/itdog-api-go";
    # Upstream does not declare a license.
    license = lib.licenses.unfree;
    mainProgram = "itdog-api-go";
  };
}
