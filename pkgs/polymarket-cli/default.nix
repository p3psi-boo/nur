{
  lib,
  stdenv,
  autoPatchelfHook,
  generated,
}:

let
  sources = {
    x86_64-linux = generated.polymarket-cli;
    aarch64-linux = generated.polymarket-cli-aarch64-linux;
  };

  sourceInfo =
    sources.${stdenv.hostPlatform.system}
      or (throw "polymarket-cli: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "polymarket-cli";
  inherit (sourceInfo) version src;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 polymarket $out/bin/polymarket
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI for Polymarket - browse markets, trade, and manage positions";
    homepage = "https://github.com/Polymarket/polymarket-cli";
    downloadPage = "https://github.com/Polymarket/polymarket-cli/releases";
    changelog = "https://github.com/Polymarket/polymarket-cli/releases/tag/${sourceInfo.version}";
    license = licenses.mit;
    mainProgram = "polymarket";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
