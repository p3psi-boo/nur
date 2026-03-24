{
  lib,
  stdenv,
  cmake,
  pkg-config,
  ffmpeg,
  libsodium,
  qt6,
  llvmPackages,
  generated,
}:

let
  sourceInfo = generated.yt-media-storage;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "yt-media-storage";
  version = sourceInfo.version;

  src = sourceInfo.src;

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    ffmpeg
    libsodium
    qt6.qtbase
  ]
  ++ lib.optional stdenv.cc.isClang llvmPackages.openmp;

  enableParallelBuilding = true;

  # Replace the core library's -march=native flag with a reproducible x86 baseline.
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail 'target_compile_options(media_storage_core PRIVATE -march=native)' \
                      'target_compile_options(media_storage_core PRIVATE -O2 -mssse3)'

    cat >> CMakeLists.txt <<'EOF'

install(TARGETS media_storage media_storage_gui
        RUNTIME DESTINATION ''${CMAKE_INSTALL_BINDIR})
EOF
  '';

  installPhase = ''
    runHook preInstall
    cmake --install . --prefix $out
    runHook postInstall
  '';

  meta = {
    description = "Store files onto YouTube by encoding them into lossless video";
    homepage = "https://github.com/PulseBeat02/yt-media-storage";
    license = lib.licenses.gpl3Only;
    mainProgram = "media_storage";
    platforms = lib.platforms.linux;
  };
})
