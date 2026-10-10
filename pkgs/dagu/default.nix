{
  lib,
  stdenvNoCC,
  generated,
  testers,
}:

let
  sourceInfo = generated."dagu-${stdenvNoCC.hostPlatform.system}";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dagu";
  inherit (sourceInfo) version src;

  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 dagu "$out/bin/dagu"
    install -Dm644 LICENSE "$out/share/licenses/dagu/LICENSE"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/dagu" version | grep -F "${finalAttrs.version}"
    runHook postInstallCheck
  '';

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "dagu version";
  };

  meta = {
    description = "Declarative workflow engine with scheduling and a built-in Web UI";
    homepage = "https://github.com/dagucloud/dagu";
    license = lib.licenses.gpl3Plus;
    mainProgram = "dagu";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
