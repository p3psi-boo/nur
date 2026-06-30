# powermem - AI Memory Plugin: Persistent, self-evolving memory for AI agents
# https://github.com/oceanbase/powermem
#
# Uses pre-built standalone binaries from GitHub Releases (PyInstaller-bundled).
# Building from source is impractical due to pyobvector (OceanBase vector library)
# not being available in nixpkgs.

{
  lib,
  stdenv,
  autoPatchelfHook,
  zlib,
  generated,
}:

let
  sourceInfo = generated.powermem;
in
stdenv.mkDerivation {
  pname = "powermem";
  inherit (sourceInfo) version src;

  sourceRoot = "powermem-${sourceInfo.version}-linux-amd64";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/powermem $out/bin/powermem
    install -Dm755 bin/powermem $out/bin/pmem
    install -Dm755 bin/powermem-server $out/bin/powermem-server
    install -Dm755 bin/powermem-mcp $out/bin/powermem-mcp

    install -Dm644 README.md $out/share/doc/powermem/README.md

    runHook postInstall
  '';

  meta = with lib; {
    description = "Persistent, self-evolving memory for AI agents and applications";
    longDescription = ''
      PowerMem combines vector, full-text, and graph retrieval with LLM-driven
      memory extraction and Ebbinghaus-style time decay. Ships two-layer
      Experience + Skill distillation for self-evolving memory, multi-agent
      isolation, user profiles, and multimodal signals (text, image, audio).

      Provides three binaries:
      - powermem (pmem): CLI client for memory ops
      - powermem-server: HTTP API server with Dashboard
      - powermem-mcp: MCP server for AI agents

      This package uses pre-built standalone binaries from GitHub Releases.
    '';
    homepage = "https://github.com/oceanbase/powermem";
    license = licenses.asl20;
    mainProgram = "powermem";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
  };
}
