{
  stdenvNoCC,
  fetchurl,
  generated,
  lib,
  autoPatchelfHook,
  modemmanager,
}:

let
  sourceInfo = generated.sigmo;
  version = lib.removePrefix "v" sourceInfo.version;

  # Platform-specific binary URLs and hashes
  sources = {
    x86_64-linux = {
      url = "https://github.com/damonto/sigmo/releases/download/${sourceInfo.version}/sigmo-linux-amd64";
      hash = "sha256-Ikl1bjgqWDMJXW8J3WQ90iWS7AsM6UHY2D3gBRSvKKo=";
    };
    aarch64-linux = {
      url = "https://github.com/damonto/sigmo/releases/download/${sourceInfo.version}/sigmo-linux-arm64";
      hash = lib.fakeHash;
    };
  };

  platform =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported platform: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "sigmo";
  inherit version;

  src = fetchurl {
    inherit (platform) url hash;
  };

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/sigmo
    runHook postInstall
  '';

  meta = {
    description = "A ModemManager management tool with eSIM support";
    homepage = "https://github.com/damonto/sigmo";
    downloadPage = "https://github.com/damonto/sigmo/releases";
    changelog = "https://github.com/damonto/sigmo/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "sigmo";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
