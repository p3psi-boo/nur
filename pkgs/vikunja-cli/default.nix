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
  version = sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = "sha256-oRpnvnlTqo0pFgTTk8vFvB659GI8qCcSFuXNaXzigbs=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${sourceInfo.version}"
  ];

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
