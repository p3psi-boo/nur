{
  lib,
  buildGo127Module,
  generated,
  installShellFiles,
  versionCheckHook,
}:

let
  sourceInfo = generated.multica-cli;
in
buildGo127Module (finalAttrs: {
  __darwinAllowLocalNetworking = true;

  pname = "multica-cli";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;
  sourceRoot = "${sourceInfo.src.name}/server";

  vendorHash = "sha256-36qJllzBV4SPln+vYOy6AJSuls5ZlTCqLAj/WPoSJgY=";

  subPackages = [ "cmd/multica" ];

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
    "-X main.commit=nixpkg"
    "-X main.date=1970-01-01T00:00:00Z"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    installShellCompletion --cmd multica \
      --bash <($out/bin/multica completion bash) \
      --zsh <($out/bin/multica completion zsh) \
      --fish <($out/bin/multica completion fish)
    install -Dm644 ../LICENSE "$out/share/licenses/${finalAttrs.pname}/LICENSE"
    install -Dm644 ../NOTICE "$out/share/doc/${finalAttrs.pname}/NOTICE"
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "CLI for the Multica managed agents platform";
    homepage = "https://github.com/multica-ai/multica";
    changelog = "https://github.com/multica-ai/multica/releases/tag/${sourceInfo.version}";
    license = {
      fullName = "Multica License";
      url = "https://github.com/multica-ai/multica/blob/${sourceInfo.version}/LICENSE";
      free = false;
      redistributable = true;
    };
    mainProgram = "multica";
  };
})
