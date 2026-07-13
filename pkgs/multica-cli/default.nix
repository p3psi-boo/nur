{
  buildGoModule,
  generated,
  installShellFiles,
  lib,
}:

let
  sourceInfo = generated.multica-cli;
  version = lib.removePrefix "v" sourceInfo.version;
in
buildGoModule {
  pname = "multica-cli";
  inherit version;

  src = sourceInfo.src;
  sourceRoot = "${sourceInfo.src.name}/server";

  vendorHash = "sha256-+IZt3ZQDHEcLA1cOcN4j4cTtIbATzAowUL3i1ZQnzBc=";

  subPackages = [ "cmd/multica" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.commit=nur"
    "-X main.date=1970-01-01T00:00:00Z"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd multica \
      --bash <($out/bin/multica completion bash) \
      --zsh <($out/bin/multica completion zsh) \
      --fish <($out/bin/multica completion fish)
  '';

  meta = {
    description = "CLI for the Multica managed agents platform";
    homepage = "https://github.com/multica-ai/multica";
    changelog = "https://github.com/multica-ai/multica/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "multica";
  };
}
