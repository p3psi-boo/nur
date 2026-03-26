{
  lib,
  fetchurl,
  fetchFromGitHub,
  generated ? null,
  jre,
  makeWrapper,
  stdenvNoCC,
}:

let
  sourceInfo =
    if generated != null && generated ? classyshark then
      generated.classyshark
    else
      rec {
        version = "8.1";
        src = fetchFromGitHub {
          owner = "google";
          repo = "android-classyshark";
          rev = version;
          hash = "sha256-bpYL6ew+k3wxsEaDX3igrB7Ij/5bDHl537G3lRJA9rY=";
        };
      };

  version = sourceInfo.version;

  jar = fetchurl {
    url = "https://github.com/google/android-classyshark/releases/download/${version}/ClassyShark.jar";
    hash = "sha256-s72UziF38kIxgwcMPdCWy5tpWnDo4E2NfTzKUw2bhV0=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "classyshark";
  inherit version;

  src = jar;

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 "$src" "$out/share/java/classyshark/ClassyShark.jar"
    makeWrapper ${lib.getExe jre} "$out/bin/classyshark" \
      --add-flags "-jar $out/share/java/classyshark/ClassyShark.jar"

    runHook postInstall
  '';

  meta = {
    description = "Standalone binary inspection tool for Android developers";
    homepage = "https://github.com/google/android-classyshark";
    changelog = "https://github.com/google/android-classyshark/releases/tag/${version}";
    license = lib.licenses.asl20;
    mainProgram = "classyshark";
    platforms = lib.platforms.all;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
  };
}
