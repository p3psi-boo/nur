{
  lib,
  fetchFromGitHub,
  generated ? null,
  jre,
  makeWrapper,
  maven,
  zip,
}:

let
  sourceInfo =
    if generated != null && generated ? uber-apk-signer then
      generated.uber-apk-signer
    else
      let
        version = "v1.3.0";
      in
      {
        inherit version;
        src = fetchFromGitHub {
          owner = "patrickfav";
          repo = "uber-apk-signer";
          rev = version;
          hash = "sha256-/dnXJFX8DArXmd4TAtVVqz2GPq456ymXe5mE678GJiY=";
        };
      };
in
maven.buildMavenPackage (finalAttrs: {
  pname = "uber-apk-signer";
  version = lib.removePrefix "v" sourceInfo.version;

  inherit jre;
  src = sourceInfo.src;

  nativeBuildInputs = [ makeWrapper zip ];

  mvnHash = "sha256-CRH5Y3lYsVBlkiVf52tjJ43/rocugRrZfF4sOnPtrD0=";
  mvnParameters = "-DcommonConfig.jarSign.skip=true -DskipTests package";

  doCheck = false;

  installPhase = ''
    runHook preInstall

    install -Dm644 "target/uber-apk-signer-${finalAttrs.version}.jar" "$out/share/java/uber-apk-signer/uber-apk-signer.jar"
    zip -qd "$out/share/java/uber-apk-signer/uber-apk-signer.jar" 'META-INF/*.RSA' 'META-INF/*.SF' 'META-INF/*.DSA'

    makeWrapper ${lib.getExe jre} "$out/bin/uber-apk-signer" \
      --add-flags "-jar $out/share/java/uber-apk-signer/uber-apk-signer.jar"

    runHook postInstall
  '';

  meta = {
    description = "CLI tool to sign, align, and verify Android APKs";
    homepage = "https://github.com/patrickfav/uber-apk-signer";
    changelog = "https://github.com/patrickfav/uber-apk-signer/releases/tag/${sourceInfo.version}";
    license = lib.licenses.asl20;
    mainProgram = "uber-apk-signer";
    platforms = lib.platforms.all;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
  };
})
