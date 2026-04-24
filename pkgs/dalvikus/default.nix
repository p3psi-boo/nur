{
  lib,
  stdenv,
  generated,
  gradle_8,
  jdk21_headless,
  jre,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
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
}:

let
  sourceInfo = generated.dalvikus;
  gradle = gradle_8.override { java = jdk21_headless; };
  runtimeLibPath = lib.makeLibraryPath [
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
  pname = "dalvikus";
  version = sourceInfo.version;

  src = sourceInfo.src;
  strictDeps = true;

  nativeBuildInputs = [
    gradle
    makeWrapper
    copyDesktopItems
  ];

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    pname = "dalvikus";
    attrPath = null;
    data = ./deps.json;
  };

  # Compose desktop build fetches native JVM dependencies during dep update.
  __darwinAllowLocalNetworking = true;

  gradleFlags = [
    "-Dfile.encoding=UTF-8"
    "-Dorg.gradle.java.home=${jdk21_headless}"
  ];
  gradleBuildTask = ":composeApp:createDistributable";
  gradleUpdateScript = ''
    gradle $gradleFlags :composeApp:createDistributable
  '';
  doCheck = false;

  desktopItems = [
    (makeDesktopItem {
      name = "dalvikus";
      exec = "dalvikus";
      icon = "dalvikus";
      desktopName = "Dalvikus";
      comment = "Android reverse-engineering tool and smali editor";
      categories = [ "Development" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    appDist="composeApp/build/compose/binaries/main/app/dalvikus"
    appRoot="$out/share/dalvikus"
    install -d "$appRoot"

    cp -r "$appDist/lib/app" "$appRoot/"

    install -Dm644 "$appDist/lib/dalvikus.png" \
      "$out/share/icons/hicolor/256x256/apps/dalvikus.png"

    makeWrapper ${lib.getExe jre} "$out/bin/dalvikus" \
      --add-flags "-Dcompose.application.configure.swing.globals=true" \
      --add-flags "-Dcompose.application.resources.dir=$appRoot/app/resources" \
      --add-flags "-Dskiko.library.path=$appRoot/app" \
      --add-flags "-Djava.library.path=$appRoot/app" \
      --add-flags "-Dapp.version=${finalAttrs.version}" \
      --set CLASSPATH "$appRoot/app/*" \
      --add-flags "MainKt" \
      --prefix LD_LIBRARY_PATH : "${runtimeLibPath}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Android reverse-engineering tool and smali editor";
    homepage = "https://github.com/loerting/dalvikus";
    changelog = "https://github.com/loerting/dalvikus/releases/tag/v${version}";
    license = licenses.gpl3Only;
    mainProgram = "dalvikus";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryBytecode
      binaryNativeCode
    ];
  };
})
