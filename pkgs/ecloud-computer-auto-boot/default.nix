{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.ecloud-computer-auto-boot;
in
buildGoModule (finalAttrs: {
  pname = "ecloud-computer-auto-boot";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  # Dependencies from gitlab.ecloud.com require network access
  # Use vendorHash = null to skip vendor hash verification
  vendorHash = null;

  # Allow network access during build
  __darwinAllowLocalNetworking = true;

  # Allow Go reference in output (needed when building with CGO_ENABLED=0)
  allowGoReference = true;

  env.CGO_ENABLED = "0";

  # Remove vendor directory and go.sum to avoid conflicts
  postUnpack = ''
    rm -rf source/vendor
    rm -f source/go.sum
  '';

  preBuild = ''
    # Force Go to use proxy for all modules, including private ones
    export GOPROXY="https://ecloud.10086.cn/api/query/developer/nexus/repository/go-sdk/,https://goproxy.cn,direct"
    export GONOSUMDB="gitlab.ecloud.com"
    export GOPRIVATE=""
    export GONOPROXY=""
    export GOFLAGS="-mod=mod"
    export GOINSECURE="gitlab.ecloud.com"

    # Regenerate go.sum with correct checksums from proxy
    go mod tidy
  '';

  ldflags = [
    "-s"
    "-w"
  ];

  subPackages = [ "." ];

  doCheck = false;

  meta = {
    description = "Auto boot tool for China Mobile eCloud Computer";
    homepage = "https://github.com/Samler-Lee/ecloud_computer_auto_boot";
    downloadPage = "https://github.com/Samler-Lee/ecloud_computer_auto_boot/releases";
    changelog = "https://github.com/Samler-Lee/ecloud_computer_auto_boot/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "ecloud_computer_auto_boot";
    platforms = lib.platforms.linux;
  };
})
