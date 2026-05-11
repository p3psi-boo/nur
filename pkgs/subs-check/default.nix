{
  buildGoModule,
  generated,
  go_1_25,
  lib,
}:

let
  sourceInfo = generated.subs-check;
in
(buildGoModule.override { go = go_1_25; }) (finalAttrs: {
  pname = "subs-check";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-JMQMqc/0Ja5BEP3wI2/2MhwaRYHKShbqAGh1V2Lzacs=";

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${finalAttrs.version}"
    "-X main.CurrentCommit=${builtins.substring 0 7 sourceInfo.version}"
  ];

  doCheck = false;

  postInstall = ''
    install -Dm644 config/config.yaml.example "$out/share/doc/${finalAttrs.pname}/config.yaml.example"
  '';

  meta = {
    description = "High-performance proxy subscription checker";
    homepage = "https://github.com/p3psi-boo/subs-check";
    changelog = "https://github.com/p3psi-boo/subs-check/commits/main/";
    license = lib.licenses.gpl3Only;
    mainProgram = "subs-check";
    platforms = lib.platforms.unix;
  };
})
