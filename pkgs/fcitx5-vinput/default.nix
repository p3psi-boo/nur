{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  gettext,
  autoPatchelfHook,
  fcitx5,
  nlohmann_json,
  cli11,
  curl,
  openssl,
  libarchive,
  pipewire,
  systemd,
  libsForQt5,
  generated,
}:

let
  sourceInfo = generated.fcitx5-vinput;
in
stdenv.mkDerivation {
  pname = "fcitx5-vinput";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    gettext
    autoPatchelfHook
    libsForQt5.wrapQtAppsHook
  ];

  buildInputs = [
    fcitx5
    nlohmann_json
    cli11
    curl
    openssl
    libarchive
    pipewire
    systemd
    libsForQt5.qtbase
    libsForQt5.qttools
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DVINPUT_PACKAGE_HOMEPAGE_URL=https://github.com/xifan2333/fcitx5-vinput"
  ];

  meta = {
    description = "Offline voice input addon for Fcitx5";
    homepage = "https://github.com/xifan2333/fcitx5-vinput";
    changelog = "https://github.com/xifan2333/fcitx5-vinput/releases/tag/${sourceInfo.version}";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "vinput";
  };
}
