{
  lib,
  generated,
  bun2nix,
}:

let
  sourceInfo = generated.mcp-cli;
in
bun2nix.mkDerivation {
  pname = "mcp-cli";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  module = "src/index.ts";
  bunCompileToBytecode = false;

  meta = with lib; {
    description = "Lightweight CLI for interacting with MCP servers";
    homepage = "https://github.com/philschmid/mcp-cli";
    downloadPage = "https://github.com/philschmid/mcp-cli/releases";
    license = licenses.mit;
    mainProgram = "mcp-cli";
    platforms = platforms.unix;
    sourceProvenance = [ sourceTypes.fromSource ];
  };
}
