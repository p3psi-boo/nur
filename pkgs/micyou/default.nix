{
  lib,
  appimageTools,
  fetchurl,
  makeDesktopItem,
  copyDesktopItems,
  generated,
}:

let
  sourceInfo = generated.micyou;
  version = lib.removePrefix "v" sourceInfo.version;
  pname = "micyou";

  src = fetchurl {
    url = "https://github.com/LanRhyme/MicYou/releases/download/v${version}/MicYou-Linux-${version}.AppImage";
    hash = "sha256-XNpIURMtcasVKopQinrKTQvDI3ULkQLKpXdjHCuYpj4=";
  };

  contents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ copyDesktopItems ];

  desktopItems = [
    (makeDesktopItem {
      name = "micyou";
      exec = "micyou";
      icon = "micyou";
      desktopName = "MicYou";
      comment = "Turn your Android device into a wireless microphone";
      categories = [
        "AudioVideo"
        "Audio"
        "Utility"
      ];
    })
  ];

  extraInstallCommands = ''
    for icon in \
      ${contents}/*.png \
      ${contents}/usr/share/icons/hicolor/*/apps/*.png
    do
      if [ -f "$icon" ]; then
        install -Dm644 "$icon" "$out/share/icons/hicolor/256x256/apps/micyou.png"
        break
      fi
    done
  '';

  meta = {
    description = "Turn your Android device into a high-quality wireless microphone for your PC";
    homepage = "https://micyou.top";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "micyou";
    maintainers = [ ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
