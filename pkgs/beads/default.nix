{
  lib,
  buildGoModule,
  generated,
  nix-update-script,
  fetchFromGitHub ? null,  # auto-passed by repo.nix, not used
}:

let
  sourceInfo = generated.beads;
in
buildGoModule (finalAttrs: {
  pname = "beads";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = "sha256-iTPi8+pbKr2Q352hzvIOGL2EneF9agrDmBwTLMUjDBE=";

  # Build from cmd/bd subdirectory
  subPackages = [ "cmd/bd" ];

  # Tests require git which we don't need for building
  doCheck = false;

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";  # 启用 x86-64-v3 指令集优化（AVX2, BMI2 等）
  };

  # 运行时性能优化：保留 -s -w 减小体积
  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
  ];

  # 启用编译器优化：激进的函数内联，提高运行时性能
  buildFlags = [ "-gcflags=all=-l=4" ];

  postInstall = ''
    mv $out/bin/bd $out/bin/beads
    ln -s $out/bin/beads $out/bin/bd
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Lightweight memory system for AI coding agents - distributed issue tracker backed by Git";
    homepage = "https://github.com/steveyegge/beads";
    changelog = "https://github.com/steveyegge/beads/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "beads";
  };
})
