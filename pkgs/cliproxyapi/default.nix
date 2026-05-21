{
  lib,
  stdenv,
  fetchurl,
  generated,
}:

let
  sourceInfo = generated.cliproxyapi;
  version = lib.removePrefix "v" sourceInfo.version;

  platform = stdenv.hostPlatform.system;
  urls = {
    x86_64-linux = {
      url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/${sourceInfo.version}/CLIProxyAPI_${version}_linux_amd64.tar.gz";
      hash = "sha256-XzH9Ex9YIyIBOWU0g5J5nDqiWUfo2O6mAt8WQ7KRUKY=";
    };
    aarch64-linux = {
      url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/${sourceInfo.version}/CLIProxyAPI_${version}_linux_aarch64.tar.gz";
      hash = "sha256-IAyWk6qovB3ozbkCHZ6rrh6hO3Urpneg+QWKIwRmTAs=";
    };
  };

  platformInfo = urls.${platform} or (throw "Unsupported platform: ${platform}");
in
stdenv.mkDerivation {
  pname = "cliproxyapi";
  inherit version;

  src = fetchurl {
    url = platformInfo.url;
    hash = platformInfo.hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -D -m755 cli-proxy-api $out/bin/cli-proxy-api
    runHook postInstall
  '';

  doCheck = false;

  meta = {
    description = "Wrap Gemini CLI, Antigravity, ChatGPT Codex, Claude Code, Grok Build as an OpenAI/Gemini/Claude/Codex compatible API service";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = "CLIProxyAPI";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
