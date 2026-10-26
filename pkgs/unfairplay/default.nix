{
  lib,
  buildGoModule,
  generated,
}:

let
  sourceInfo = generated.unfairplay;
in
buildGoModule (finalAttrs: {
  pname = "unfairplay";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-NuEbHINCBlyYFJUMyNw/SzxLXd+jzq3gOMEETTuzMsg=";

  subPackages = [ "cmd/unfairplay" ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
  };

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  # subPackages would otherwise limit `go test` to the CLI wrapper.
  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';

  postInstall = ''
    install -Dm644 -t "$out/share/doc/unfairplay" \
      README.md LICENSE LICENSE-DARKPHOENIX.txt NOTICE
  '';

  meta = {
    description = "Recover a FairPlay enrollment model and decrypt personalized iOS IPAs";
    homepage = "https://github.com/DrWhax/unfairplay";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "unfairplay";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
