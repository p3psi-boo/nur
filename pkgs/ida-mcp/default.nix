# ida-mcp - Headless IDA Pro MCP Server
# https://github.com/blacktop/ida-mcp-rs

{ lib
, stdenv
, generated
, autoPatchelfHook
, makeWrapper
, zlib
, ida-pro
}:

let
  sourceInfo = generated.ida-mcp;
in
stdenv.mkDerivation {
  pname = "ida-mcp";
  version = sourceInfo.version;

  src = sourceInfo.src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    zlib
    stdenv.cc.cc.lib
  ];

  # Runtime dependencies for autoPatchelf (excluding IDA libraries)
  runtimeDependencies = [
    stdenv.cc.cc.lib
  ];

  # Ignore IDA libraries during patchelf - they are loaded at runtime
  autoPatchelfIgnoreMissingDeps = [
    "libida.so"
    "libidalib.so"
  ];

  # The tarball contains flat files (not a directory)
  dontUnpack = false;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ida-mcp $out/bin/

    # The binary has RPATH baked in for common IDA installation paths
    # We wrap it to ensure it can find IDA libraries at runtime
    wrapProgram $out/bin/ida-mcp \
      --prefix LD_LIBRARY_PATH : "${ida-pro}/opt:$LD_LIBRARY_PATH" \
      --set-default IDADIR "${ida-pro}/opt"

    # Install documentation
    mkdir -p $out/share/doc/ida-mcp
    cp README.md LICENSE $out/share/doc/ida-mcp/ 2>/dev/null || true

    runHook postInstall
  '';

  meta = with lib; {
    description = "Headless IDA Pro MCP Server for AI-powered reverse engineering";
    longDescription = ''
      A headless MCP (Model Context Protocol) server for IDA Pro 9.2+.
      Enables AI assistants to interact with IDA Pro for automated reverse
      engineering tasks including disassembly, decompilation, and binary analysis.

      Requires IDA Pro 9.2+ with valid license.

      The binary has baked-in RPATH for common IDA installation paths:
      - /opt/idapro-9.3, /opt/idapro-9.2
      - $HOME/idapro-9.3, $HOME/idapro-9.2
      - /usr/local/idapro-9.3, /usr/local/idapro-9.2

      If your IDA is installed elsewhere, set IDADIR environment variable:
        export IDADIR=/path/to/ida

      To use with Claude Code:
        claude mcp add ida -- ida-mcp

      To use with Cursor, add to .cursor/mcp.json:
        {
          "mcpServers": {
            "ida": { "command": "ida-mcp" }
          }
        }
    '';
    homepage = "https://github.com/blacktop/ida-mcp-rs";
    license = licenses.mit;
    mainProgram = "ida-mcp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
