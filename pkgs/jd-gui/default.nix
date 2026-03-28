{
  lib,
  fetchFromGitHub,
  fetchurl,
  generated ? null,
  jre,
  makeWrapper,
  stdenvNoCC,
}:

let
  sourceInfo =
    if generated != null && generated ? jd-gui then
      generated.jd-gui
    else
      let
        version = "v1.6.6";
      in
      {
        inherit version;
        src = fetchFromGitHub {
          owner = "java-decompiler";
          repo = "jd-gui";
          rev = version;
          hash = lib.fakeHash;
        };
      };

  version = lib.removePrefix "v" sourceInfo.version;
  jar = fetchurl {
    url = "https://github.com/java-decompiler/jd-gui/releases/download/${sourceInfo.version}/jd-gui-${version}.jar";
    hash = "sha256-LJ0++osGQ4pyhBOfaPbvy/sqEeC50gozcNUBiWha/As=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "jd-gui";
  inherit version;

  src = jar;

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 "$src" "$out/share/java/jd-gui/jd-gui.jar"
    makeWrapper ${lib.getExe jre} "$out/bin/jd-gui" \
      --add-flags "-jar $out/share/java/jd-gui/jd-gui.jar"

    runHook postInstall
  '';

  meta = {
    description = "Standalone graphical utility that displays Java source code from class files";
    homepage = "https://github.com/java-decompiler/jd-gui";
    changelog = "https://github.com/java-decompiler/jd-gui/releases/tag/${sourceInfo.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "jd-gui";
    platforms = lib.platforms.all;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
  };
}
