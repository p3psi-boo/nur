{
  generated,
  lib,
  buildGoModule,
}:

let
  sourceInfo = generated.beads_viewer;
in
buildGoModule {
  pname = "beads_viewer";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  # Upstream has a stale vendor directory - use proxyVendor to ignore it
  proxyVendor = true;
  vendorHash = null;
  # Build from cmd/beads_viewer subdirectory if it exists
  # subPackages = [ "cmd/beads_viewer" ];

  # Tests may require additional setup
  doCheck = false;

  # 运行时性能优化
  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
  };

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${sourceInfo.version}"
  ];

  buildFlags = [ "-gcflags=all=-l=4" ];

  meta = {
    description = "TUI application for viewing and managing Beads task management system";
    homepage = "https://github.com/Dicklesworthstone/beads_viewer";
    changelog = "https://github.com/Dicklesworthstone/beads_viewer/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "bv";
  };
}
