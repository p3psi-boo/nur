{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.vja;
in
buildGoModule {
  pname = "vja";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-UGqqyMt8dEtILYEskblkNJKDk7h+QHZMsNZX/C1W5aI=";

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
      mv "$out/bin/vikunja-cli" "$out/bin/vja"
    fi
  '';

  meta = {
    description = "Stateless CLI for Vikunja";
    homepage = "https://github.com/p3psi-boo/vikunja-cli";
    license = lib.licenses.wtfpl;
    mainProgram = "vja";
  };
}
