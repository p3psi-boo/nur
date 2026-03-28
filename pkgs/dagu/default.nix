{
  buildGoModule,
  generated,
  go_1_26,
  lib,
}:

let
  sourceInfo = generated.dagu;
in
(buildGoModule.override { go = go_1_26; }) (finalAttrs: {
  pname = "dagu";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  subPackages = [ "cmd" ];

  # 运行时性能优化环境
  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";  # x86-64-v3 指令集优化
  };

  vendorHash = "sha256-VZlskGF/qsZ8UeaGuaWF9+biAHcdxo34wmQJeFua+c8=";

  # 运行时性能优化
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${sourceInfo.version}"
  ];

  # 启用激进内联优化
  buildFlags = [ "-gcflags=all=-l=4" ];

  postInstall = ''
    if [ -e "$out/bin/cmd" ]; then
      mv "$out/bin/cmd" "$out/bin/dagu"
    fi
  '';

  doCheck = false;

  meta = {
    description = "Self-contained, lightweight workflow engine";
    homepage = "https://github.com/dagu-org/dagu";
    changelog = "https://docs.dagu.sh/reference/changelog";
    license = lib.licenses.gpl3Only;
    mainProgram = "dagu";
  };
})
