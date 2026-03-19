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

  # Replace -march=native with -mssse3 for reproducibility
  # SSSE3 is required by wirehair library's SIMD code
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail 'target_compile_options(media_storage PRIVATE -march=native)' \
                      'target_compile_options(media_storage PRIVATE -O2 -mssse3)'
  '';

  # Upstream CMakeLists.txt has no install() rules
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp media_storage media_storage_gui $out/bin/
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
