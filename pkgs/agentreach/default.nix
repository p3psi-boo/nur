{
  lib,
  buildGoModule,
  generated,
}:

let
  sourceInfo = generated.agentreach;
  version = lib.removePrefix "v" sourceInfo.version;
in
buildGoModule {
  pname = "agentreach";
  inherit version;

  src = sourceInfo.src;
  vendorHash = null;

  env.CGO_ENABLED = "0";

  subPackages = [
    "cmd/reach"
    "cmd/reach-helper"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.buildVersion=${version}"
    "-X main.buildCommit=${sourceInfo.version}"
    "-X main.version=${version}"
  ];

  # The generated wrapper in this test uses /usr/bin/env, which is unavailable
  # in the Nix sandbox; keep the remaining upstream tests enabled.
  checkFlags = [ "-skip=TestShimPassthroughLeavesTheSeamArmed" ];

  meta = {
    description = "Run coding agents locally while their work happens on a remote SSH target";
    homepage = "https://github.com/bojieli/agentreach";
    license = lib.licenses.mit;
    mainProgram = "reach";
    platforms = lib.platforms.unix;
  };
}
