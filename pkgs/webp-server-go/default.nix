{
  buildGo127Module,
  generated,
  lib,
  pkg-config,
  vips,
}:

let
  sourceInfo = generated.webp-server-go;
  version = "0-unstable-${sourceInfo.date}";
in
buildGo127Module {
  pname = "webp-server-go";
  inherit version;

  src = sourceInfo.src;
  vendorHash = "sha256-gXtDJEPdS2bYiRtjl7/Wq7Vi18i+AxrEfPTqvLRHLD8=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ vips ];

  env.GOFLAGS = "-trimpath";

  ldflags = [
    "-s"
    "-w"
    "-X=webp_server_go/config.Version=${version}"
  ];

  # Several upstream tests fetch remote images, which is unavailable in Nix's
  # network-sandboxed check phase.
  doCheck = false;

  postInstall = ''
    mv $out/bin/webp_server_go $out/bin/webp-server
  '';

  meta = {
    description = "On-the-fly WebP, AVIF, and JXL image conversion server";
    homepage = "https://github.com/webp-sh/webp_server_go";
    license = lib.licenses.gpl3Only;
    mainProgram = "webp-server";
    platforms = lib.platforms.linux;
  };
}
