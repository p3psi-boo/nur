{
  lib,
  stdenv,
  fetchzip,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  jdk17,
  libpulseaudio,
  alsa-lib,
  fontconfig,
  freetype,
  libGL,
  libxkbcommon,
  libx11,
  libxcursor,
  libxext,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  ...
}:

let
  runtimeLibPath = lib.makeLibraryPath [
    libpulseaudio
    alsa-lib
    fontconfig
    freetype
    libGL
    libxkbcommon
    libx11
    libxcursor
    libxext
    libxi
    libxrandr
    libxrender
    libxtst
    stdenv.cc.cc.lib
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "micyou";
  version = "1.1.5";

  # Use the Linux NoJRE build - users need to provide their own JDK
  src = fetchzip {
    url = "https://github.com/LanRhyme/MicYou/releases/download/v${finalAttrs.version}/MicYou-Linux-NoJRE-${finalAttrs.version}.tar.gz";
    sha256 = "sha256-iZH66Y4650OfVfgmS0x8REfKiu4/oiLRRtfJ12NHkKc=";
  };

  nativeBuildInputs = [ makeWrapper copyDesktopItems ];

  buildInputs = [
    libpulseaudio
    alsa-lib
  ];

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

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/micyou
    cp -r . $out/lib/micyou/

    # Make the shell script executable
    chmod +x $out/lib/micyou/MicYou.sh

    mkdir -p $out/bin
    makeWrapper $out/lib/micyou/MicYou.sh $out/bin/micyou \
      --prefix PATH : ${lib.makeBinPath [ jdk17 ]} \
      --prefix LD_LIBRARY_PATH : ${runtimeLibPath} \
      --set JAVA_HOME ${jdk17.home}

    # Extract upstream app icon from bundled JAR resources for desktop integration.
    tmpDir="$(mktemp -d)"
    (
      cd "$tmpDir"
      ${jdk17}/bin/jar xf "$out/lib/micyou/lib/MicYou.jar" \
        composeResources/micyou.composeapp.generated.resources/drawable/app_icon.png
    )

    install -Dm644 \
      "$tmpDir/composeResources/micyou.composeapp.generated.resources/drawable/app_icon.png" \
      "$out/share/icons/hicolor/256x256/apps/micyou.png"

    rm -rf "$tmpDir"

    runHook postInstall
  '';

  meta = {
    description = "Turn your Android device into a high-quality wireless microphone for your PC";
    homepage = "https://micyou.top";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "micyou";
    maintainers = [ ];
  };
})
