# mebox - self-hosted personal media center for NAS / home theater
# https://github.com/truewhile/MeBox
{
  lib,
  buildGoModule,
  buildNpmPackage,
  generated,
  go_1_25,
  nodejs_22,
  makeBinaryWrapper,
  ffmpeg-headless,
}:

let
  sourceInfo = generated.mebox;
  version = lib.removePrefix "mebox-v" sourceInfo.version;

  meboxWeb = (buildNpmPackage.override { nodejs = nodejs_22; }) {
    pname = "mebox-web";
    inherit version;
    inherit (sourceInfo) src;
    sourceRoot = "${sourceInfo.src.name}/web";

    npmDepsHash = "sha256-5pfajjjr9/sq0MoVCNxQmB8DYLbxyFUOFqQb6M8KTdU=";

    env.CI = "true";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist "$out/"
      runHook postInstall
    '';

    meta = {
      description = "MeBox web frontend";
      homepage = "https://github.com/truewhile/MeBox";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.all;
    };
  };
in
(buildGoModule.override { go = go_1_25; }) {
  pname = "mebox";
  inherit version;
  inherit (sourceInfo) src;

  vendorHash = "sha256-OaALK2dpiiN3ZKTy+seJ3btiPymccU9LZ+sby5F0Lq8=";

  subPackages = [ "cmd/server" ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  nativeBuildInputs = [ makeBinaryWrapper ];

  preBuild = ''
    mkdir -p web/dist
    cp -r ${meboxWeb}/dist/. web/dist/
  '';

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=mebox-v${version}"
  ];

  postInstall = ''
    mv "$out/bin/server" "$out/bin/mebox"
    wrapProgram "$out/bin/mebox" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]} \
      --set-default MEBOX_APP_FFMPEG_PATH ${lib.getExe ffmpeg-headless} \
      --set-default MEBOX_APP_FFPROBE_PATH ${lib.getExe' ffmpeg-headless "ffprobe"}
  '';

  passthru = {
    web = meboxWeb;
  };

  meta = {
    description = "Self-hosted personal media center for NAS and home theater";
    longDescription = ''
      MeBox is a self-hosted media library with metadata scraping, HLS
      transcoding, Emby/Jellyfin client compatibility, cloud-drive STRM
      playback, and multi-user permissions.
    '';
    homepage = "https://github.com/truewhile/MeBox";
    changelog = "https://github.com/truewhile/MeBox/releases/tag/${sourceInfo.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "mebox";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
