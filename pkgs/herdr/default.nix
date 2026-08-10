{
  lib,
  stdenv,
  generated,
}:

let
  sources = {
    x86_64-linux = generated.herdr;
    aarch64-linux = generated.herdr-aarch64-linux;
  };

  sourceInfo =
    sources.${stdenv.hostPlatform.system}
      or (throw "herdr: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "herdr";
  inherit (sourceInfo) version src;

  # herdr 官方发布的是 static-pie 单文件二进制，无需解包
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/herdr
    runHook postInstall
  '';

  meta = with lib; {
    description = "The runtime your coding agents live on — agent multiplexer in your terminal";
    homepage = "https://herdr.dev";
    downloadPage = "https://github.com/herdrdev/herdr/releases";
    changelog = "https://github.com/herdrdev/herdr/releases/tag/${sourceInfo.version}";
    license = licenses.asl20;
    mainProgram = "herdr";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
