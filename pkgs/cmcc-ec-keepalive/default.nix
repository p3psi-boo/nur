{
  lib,
  buildGoModule,
  generated,
}:

let
  sourceInfo = generated.cmcc-ec-keepalive;
in
buildGoModule {
  pname = "cmcc-ec-keepalive";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = "sha256-agXTerjfyDS92ijN+nIfqq+WkjjIryPq8uIN+I0d3J0=";

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    if [ -f "$out/bin/ecloud-cloudpc-keepalive" ]; then
      mv "$out/bin/ecloud-cloudpc-keepalive" "$out/bin/cmcc-ec-keepalive"
    fi
    ln -s "cmcc-ec-keepalive" "$out/bin/cmcc-ctl"
  '';

  meta = {
    description = "中国移动云电脑 Keepalive 守护进程及 CLI 控制工具";
    homepage = "https://github.com/p3psi-boo/cmcc-ec-keepalive";
    license = lib.licenses.mit;
    mainProgram = "cmcc-ec-keepalive";
    platforms = lib.platforms.unix;
  };
}
