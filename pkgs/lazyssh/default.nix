{
  lib,
  buildGoModule,
  generated,
}:
let
  sourceInfo = generated.lazyssh;
  gitCommit = sourceInfo.version;
in
buildGoModule (finalAttrs: {
  pname = "lazyssh";
  version = "unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-OMlpqe7FJDqgppxt4t8lJ1KnXICOh6MXVXoKkYJ74Ks=";

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3"; # x86-64-v3 指令集优化
  };

  # 运行时性能优化
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
    "-X=main.gitCommit=${gitCommit}"
  ];

  # 启用激进内联优化
  buildFlags = [ "-gcflags=all=-l=4" ];

  postInstall = ''
    mv $out/bin/cmd $out/bin/lazyssh
  '';

  meta = {
    description = "Terminal-based SSH manager";
    homepage = "https://github.com/p3psi-boo/lazyssh";
    changelog = "https://github.com/p3psi-boo/lazyssh/commit/${gitCommit}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ kpbaks ];
    mainProgram = "lazyssh";
  };
})
