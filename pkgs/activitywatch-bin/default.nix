{
  lib,
  stdenvNoCC,
  undmg,
  generated,
}:

stdenvNoCC.mkDerivation {
  pname = "activitywatch-bin";
  version = lib.removePrefix "v" generated.activitywatch-bin.version;
  inherit (generated.activitywatch-bin) src;

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  dontBuild = true;

  # Keep the signed application bundle intact, including its bundled Python
  # runtime, frameworks and helper executables.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -R ActivityWatch.app "$out/Applications/"

    for program in aw-qt aw-watcher-afk aw-watcher-window; do
      test -x "$out/Applications/ActivityWatch.app/Contents/MacOS/$program"
      ln -s "../Applications/ActivityWatch.app/Contents/MacOS/$program" "$out/bin/$program"
    done

    test -x "$out/Applications/ActivityWatch.app/Contents/Frameworks/aw-server-rust"
    ln -s "../Applications/ActivityWatch.app/Contents/Frameworks/aw-server-rust" "$out/bin/aw-server-rust"

    runHook postInstall
  '';

  meta = {
    description = "ActivityWatch time tracker, official Apple Silicon application bundle";
    homepage = "https://activitywatch.net/";
    changelog = "https://github.com/ActivityWatch/activitywatch/releases/tag/${generated.activitywatch-bin.version}";
    license = lib.licenses.mpl20;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "aw-qt";
  };
}
