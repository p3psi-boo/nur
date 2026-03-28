{
  lib,
  stdenv,
  stdenvNoCC,
  generated,
  makeWrapper,
  dpkg,
  jdk,
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
stdenvNoCC.mkDerivation {
  pname = "dalvikus";
  version = sourceInfo.version;

  src = sourceInfo.src;
  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
    dpkg
  ];

  installPhase = ''
    runHook preInstall

    dpkg-deb -x "$src" unpacked

    appRoot="$out/share/dalvikus"
    install -d "$appRoot"
    cp -r unpacked/opt/dalvikus/lib/app "$appRoot/"

    install -Dm644 unpacked/opt/dalvikus/lib/dalvikus.png \
      "$out/share/icons/hicolor/256x256/apps/dalvikus.png"
    install -d "$out/share/applications"

    cat > "$out/share/applications/dalvikus.desktop" <<EOF
[Desktop Entry]
Name=Dalvikus
Comment=Android reverse-engineering tool and smali editor
Exec=$out/bin/dalvikus
Icon=dalvikus
Terminal=false
Type=Application
Categories=Development;
EOF

    makeWrapper ${lib.getExe jdk} "$out/bin/dalvikus" \
      --add-flags "-Dcompose.application.configure.swing.globals=true" \
      --add-flags "-Dcompose.application.resources.dir=$appRoot/app/resources" \
      --add-flags "-Dskiko.library.path=$appRoot/app" \
      --add-flags "-Djava.library.path=$appRoot/app" \
      --add-flags "-Dapp.version=${sourceInfo.version}" \
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
      binaryBytecode
      binaryNativeCode
    ];
  };
}
