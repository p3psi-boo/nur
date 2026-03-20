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
  sherpa-onnx,
  onnxruntime,
  generated,
}:

let
  sourceInfo = generated.fcitx5-vinput;
in
stdenv.mkDerivation {
  pname = "fcitx5-vinput";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  postPatch = ''
    substituteInPlace src/daemon/asr_engine.cpp \
      --replace-fail \
        'if (!f_merged_decoder.empty()) {' \
        'if (!f_merged_decoder.empty() && f_cached_decoder.empty()) {' \
      --replace-fail \
        'config.model_config.moonshine.merged_decoder = f_merged_decoder.c_str();' \
        'config.model_config.moonshine.cached_decoder = f_merged_decoder.c_str();' \
      --replace-fail \
        '      config.model_config.fire_red_asr_ctc.model = f_model.c_str();' \
        '      fprintf(stderr,
              "vinput: fire_red_asr_ctc is not supported by the installed "
              "sherpa-onnx; provide encoder/decoder model files\n");' \
      --replace-fail \
        '      config.model_config.model_type = "fire_red_asr_ctc";' \
        '      return false;'
  '';

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
    sherpa-onnx
    onnxruntime
  ];
  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DVINPUT_PACKAGE_HOMEPAGE_URL=https://github.com/xifan2333/fcitx5-vinput"
    "-DVINPUT_BUNDLE_SHERPA_RUNTIME=OFF"
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
