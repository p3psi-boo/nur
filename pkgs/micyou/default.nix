{
  lib,
  stdenv,
  fetchzip,
  makeWrapper,
  jdk17,
  libpulseaudio,
  alsa-lib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "micyou";
  version = "1.1.5";

  # Use the Linux NoJRE build - users need to provide their own JDK
  src = fetchzip {
    url = "https://github.com/LanRhyme/MicYou/releases/download/v${finalAttrs.version}/MicYou-Linux-NoJRE-${finalAttrs.version}.tar.gz";
    sha256 = "sha256-iZH66Y4650OfVfgmS0x8REfKiu4/oiLRRtfJ12NHkKc=";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    libpulseaudio
    alsa-lib
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
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libpulseaudio alsa-lib ]} \
      --set JAVA_HOME ${jdk17.home}

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
