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

  vendorHash = lib.fakeHash;

  allowGoReference = true;

  env = {
    CGO_ENABLED = "0";
    GOENV = "off";
    GOPROXY = "https://ecloud.10086.cn/api/query/developer/nexus/repository/go-sdk/,https://goproxy.cn,direct";
    GONOSUMDB = "gitlab.ecloud.com";
    GOPRIVATE = "none";
    GONOPROXY = "none";
    GOINSECURE = "none";
    GOAMD64 = "v3";  # 新增：x86-64-v3 指令集优化
  };

  ldflags = [
    "-s"
    "-w"
  ];

  buildFlags = [ "-gcflags=all=-l=4" ];  # 新增：激进内联优化

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
