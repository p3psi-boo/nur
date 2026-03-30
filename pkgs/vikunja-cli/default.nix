{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.vikunja-cli;
in
buildGoModule {
  pname = "vikunja-cli";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-oRpnvnlTqo0pFgTTk8vFvB659GI8qCcSFuXNaXzigbs=";

  # 运行时性能优化
  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
  };

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${sourceInfo.version}"
  ];

  buildFlags = [ "-gcflags=all=-l=4" ];

  postInstall = ''
    if [ -f "$out/bin/vikunja-cli" ]; then
      ln -s "$out/bin/vikunja-cli" "$out/bin/vja"
    fi
  '';

  meta = {
    description = "Stateless CLI for Vikunja";
    homepage = "https://github.com/p3psi-boo/vikunja-cli";
    license = lib.licenses.wtfpl;
    mainProgram = "vja";
  };
}
