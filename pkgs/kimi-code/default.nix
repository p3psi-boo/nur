{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
  generated,
  unzip,
}:

let
  sources = {
    x86_64-linux = generated.kimi-code-linux-x64;
    aarch64-linux = generated.kimi-code-linux-arm64;
    x86_64-darwin = generated.kimi-code-darwin-x64;
    aarch64-darwin = generated.kimi-code-darwin-arm64;
  };

  sourceInfo =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "kimi-code: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "kimi-code";
  inherit (sourceInfo) version src;

  nativeBuildInputs = [ unzip ] ++ lib.optionals stdenvNoCC.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.isLinux [ stdenvNoCC.cc.cc.lib ];

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    runHook postUnpack
  '';

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 kimi "$out/bin/kimi"
    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding agent CLI that runs in your terminal (by Moonshot AI)";
    homepage = "https://github.com/MoonshotAI/kimi-code";
    changelog = "https://github.com/MoonshotAI/kimi-code/releases/tag/%40moonshot-ai%2Fkimi-code%40${sourceInfo.version}";
    license = licenses.mit;
    mainProgram = "kimi";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
