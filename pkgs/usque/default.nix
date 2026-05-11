{
  lib,
  stdenv,
  buildGoModule,
  go_1_25,
  generated,
  installShellFiles,
}:

let
  sourceInfo = generated.usque;
in
(buildGoModule.override { go = go_1_25; }) (finalAttrs: {
  pname = "usque";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-29f/5PnmqaVS8PP1xVksgszFk3GyYZXXGDD1hjE/iSA=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/Diniboy1123/usque/cmd.version=${finalAttrs.version}"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd usque \
      --bash <($out/bin/usque completion bash) \
      --fish <($out/bin/usque completion fish) \
      --zsh <($out/bin/usque completion zsh)
  '';

  meta = {
    mainProgram = "usque";
    description = "Open-source reimplementation of the Cloudflare WARP client's MASQUE protocol";
    homepage = "https://github.com/Diniboy1123/usque";
    license = lib.licenses.mit;
    changelog = "https://github.com/Diniboy1123/usque/commits/main/";
  };
})
