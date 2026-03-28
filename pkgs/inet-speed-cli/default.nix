{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.inet-speed-cli;
in
buildGoModule {
  pname = "inet-speed-cli";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  subPackages = [ "cmd/speedtest" ];

  vendorHash = "sha256-cBeQjwX2x+G/huBBJa+9/TemOKhO1eP8hKiUYEAfEFM=";

  # 运行时性能优化
  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
  };

  buildFlags = [ "-gcflags=all=-l=4" ];

  postInstall = ''
    mv "$out/bin/speedtest" "$out/bin/inetspeed-cli"
  '';

  meta = {
    description = "Apple CDN download/upload/latency speedtest CLI";
    homepage = "https://github.com/tsosunchia/iNetSpeed-CLI";
    license = lib.licenses.gpl3Plus;
    mainProgram = "inetspeed-cli";
  };
}
