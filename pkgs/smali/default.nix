{
  lib,
  stdenv,
  fetchFromGitHub,
  generated ? null,
  gradle_8,
  jdk17_headless,
  jre_headless,
  makeWrapper,
  python3,
  zip,
}:

let
  sourceInfo =
    if generated != null && generated ? smali then
      generated.smali
    else
      rec {
        version = "v2.5.2";
        src = fetchFromGitHub {
          owner = "JesusFreke";
          repo = "smali";
          rev = version;
          hash = "sha256-UkABsX7KaDZyFR4MTmpjnw4dGXChbLB281Kav/k7/00=";
        };
      };

  gradle = gradle_8.override { java = jdk17_headless; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "smali";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;
  strictDeps = true;

  nativeBuildInputs = [
    gradle
    makeWrapper
    python3
    zip
  ];

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    pname = "smali";
    attrPath = null;
    data = ./deps.json;
  };

  __darwinAllowLocalNetworking = true;

  postPatch = ''
    substituteInPlace build.gradle \
      --replace-fail "if (!('release' in gradle.startParameter.taskNames)) {" "if (false) {" \
      --replace-fail "classpath 'org.eclipse.jgit:org.eclipse.jgit:2.0.0.201206130900-r'" ""

    python - <<'PY'
from pathlib import Path

baksmali = Path("baksmali/build.gradle")
text = baksmali.read_text()
text = text.replace("    classifier = 'fat'\n", "    archiveClassifier = 'fat'\n")
text = text.replace(
    """    doLast {\n        if (!System.getProperty('os.name').toLowerCase().contains('windows')) {\n            ant.symlink(link: file(\"''${destinationDirectory.get()}/baksmali.jar\"), resource: archivePath, overwrite: true)\n        }\n    }\n}""",
    """    doLast {\n        if (!System.getProperty('os.name').toLowerCase().contains('windows')) {\n            ant.symlink(link: file(\"''${destinationDirectory.get()}/baksmali.jar\"), resource: archivePath, overwrite: true)\n        }\n    }\n\n    dependsOn project(':util').jar\n    dependsOn project(':dexlib2').jar\n}""",
)
baksmali.write_text(text)

smali = Path("smali/build.gradle")
text = smali.read_text()
text = text.replace(
    "processResources.expand('version': version)\n",
    "processResources.expand('version': version)\nprocessResources.configure {\n    dependsOn generateGrammarSource\n}\n",
)
text = text.replace("    classifier = 'fat'\n", "    archiveClassifier = 'fat'\n")
text = text.replace(
    """    doLast {\n        if (!System.getProperty('os.name').toLowerCase().contains('windows')) {\n            ant.symlink(link: file(\"''${destinationDirectory.get()}/smali.jar\"), resource: archivePath, overwrite: true)\n        }\n    }\n}""",
    """    doLast {\n        if (!System.getProperty('os.name').toLowerCase().contains('windows')) {\n            ant.symlink(link: file(\"''${destinationDirectory.get()}/smali.jar\"), resource: archivePath, overwrite: true)\n        }\n    }\n\n    dependsOn project(':util').jar\n    dependsOn project(':dexlib2').jar\n}""",
)
smali.write_text(text)
PY
  '';

  gradleFlags = [ "-Dfile.encoding=UTF-8" ];
  gradleBuildTask = ":smali:fatJar :baksmali:fatJar";
  doCheck = false;

  installPhase = ''
    runHook preInstall

    install -Dm644 smali/build/libs/*-fat.jar "$out/share/java/smali/smali.jar"
    install -Dm644 baksmali/build/libs/*-fat.jar "$out/share/java/smali/baksmali.jar"

    zip -qd "$out/share/java/smali/smali.jar" 'META-INF/*.RSA' 'META-INF/*.SF' 'META-INF/*.DSA' || true
    zip -qd "$out/share/java/smali/baksmali.jar" 'META-INF/*.RSA' 'META-INF/*.SF' 'META-INF/*.DSA' || true

    makeWrapper ${lib.getExe jre_headless} "$out/bin/smali" \
      --add-flags "-jar $out/share/java/smali/smali.jar"

    makeWrapper ${lib.getExe jre_headless} "$out/bin/baksmali" \
      --add-flags "-jar $out/share/java/smali/baksmali.jar"

    runHook postInstall
  '';

  meta = {
    description = "Assembler and disassembler for Android's dex format";
    homepage = "https://github.com/JesusFreke/smali";
    changelog = "https://github.com/JesusFreke/smali/releases/tag/${sourceInfo.version}";
    license = with lib.licenses; [
      asl20
      bsd3
    ];
    mainProgram = "smali";
    platforms = lib.platforms.all;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
  };
})
