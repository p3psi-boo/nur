{
  lib,
  stdenv,
  makeWrapper,
  autoPatchelfHook,
  generated,
}:

let
  sources = {
    x86_64-linux = generated.agent-browser;
    aarch64-linux = generated.agent-browser-linux-arm64;
    x86_64-darwin = generated.agent-browser-darwin-x64;
    aarch64-darwin = generated.agent-browser-darwin-arm64;
  };

  sourceInfo =
    sources.${stdenv.hostPlatform.system}
      or (throw "agent-browser: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "agent-browser";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/libexec/agent-browser/agent-browser"

    makeWrapper "$out/libexec/agent-browser/agent-browser" "$out/bin/agent-browser" \
      --set AGENT_BROWSER_NATIVE 1

    runHook postInstall
  '';

  meta = with lib; {
    description = "Browser automation CLI for AI agents";
    homepage = "https://agent-browser.dev";
    license = licenses.asl20;
    platforms = builtins.attrNames sources;
    mainProgram = "agent-browser";
  };
}
