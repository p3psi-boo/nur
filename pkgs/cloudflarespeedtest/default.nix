{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.cloudflarespeedtest;
in
buildGoModule (finalAttrs: {
  pname = "cloudflare-speedtest";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  subPackages = [ "." ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";  # x86-64-v3 指令集优化（AVX2, BMI2）
  };

  vendorHash = "sha256-4h3Jf3K6uEm79KAy46v69wby01zf2tfdZxGeTyUXvdk=";

  ldflags = [
    "-s"
    "-w"
  ];

  # 启用激进内联优化
  buildFlags = [ "-gcflags=all=-l=4" ];

  doCheck = false;

  postInstall = ''
    if [ -e "$out/bin/CloudflareSpeedTest" ] && [ ! -e "$out/bin/CloudflareST" ]; then
      mv "$out/bin/CloudflareSpeedTest" "$out/bin/CloudflareST"
    fi
  '';

  meta = {
    description = "Cloudflare speed test tool";
    homepage = "https://github.com/XIU2/CloudflareSpeedTest";
    downloadPage = "https://github.com/XIU2/CloudflareSpeedTest/releases";
    license = lib.licenses.gpl3Only;
    mainProgram = "CloudflareST";
  };
})
