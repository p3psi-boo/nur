{
  lib,
  stdenvNoCC,
  generated,
}:

let
  sources = {
    x86_64-linux = generated.fff-mcp;
    aarch64-linux = generated.fff-mcp-aarch64-linux;
    x86_64-darwin = generated.fff-mcp-darwin-x64;
    aarch64-darwin = generated.fff-mcp-darwin-arm64;
  };

  sourceInfo =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "fff-mcp: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "fff-mcp";
  inherit (sourceInfo) version src;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/fff-mcp"

    runHook postInstall
  '';

  meta = with lib; {
    description = "MCP server for fff.nvim";
    homepage = "https://github.com/dmtrKovalenko/fff.nvim";
    downloadPage = "https://github.com/dmtrKovalenko/fff.nvim/releases";
    changelog = "https://github.com/dmtrKovalenko/fff.nvim/releases/tag/v${sourceInfo.version}";
    license = licenses.mit;
    mainProgram = "fff-mcp";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
