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
  version = "unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  subPackages = [ "." ];

  env = {
    CGO_ENABLED = "0";
  };

  vendorHash = "sha256-4h3Jf3K6uEm79KAy46v69wby01zf2tfdZxGeTyUXvdk=";

  ldflags = [
    "-s"
    "-w"
  ];

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
