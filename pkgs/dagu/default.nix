{
  lib,
  stdenv,
  fetchurl,
  generated,
}:

let
  sourceInfo = generated.dagu;
  version = lib.removePrefix "v" sourceInfo.version;

  platform = stdenv.hostPlatform.system;
  urls = {
    x86_64-linux = {
      url = "https://github.com/dagucloud/dagu/releases/download/${sourceInfo.version}/dagu_${version}_linux_amd64.tar.gz";
      hash = "sha256-xkko+0Q5SnHNKyEC7g07uPso7/f2cetdp2kAkeK8Cyg=";
    };
    aarch64-linux = {
      url = "https://github.com/dagucloud/dagu/releases/download/${sourceInfo.version}/dagu_${version}_linux_arm64.tar.gz";
      hash = "sha256-bAUjISCEa+cy1riaftLetPWUAE2FL1abEvBSZgzihJs=";
    };
  };

  platformInfo = urls.${platform} or (throw "Unsupported platform: ${platform}");
in
stdenv.mkDerivation {
  pname = "dagu";
  inherit version;

  src = fetchurl {
    url = platformInfo.url;
    hash = platformInfo.hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -D -m755 dagu $out/bin/dagu
    runHook postInstall
  '';

  doCheck = false;

  meta = {
    description = "Self-contained, lightweight workflow engine";
    homepage = "https://github.com/dagu-org/dagu";
    changelog = "https://docs.dagu.sh/reference/changelog";
    license = lib.licenses.gpl3Only;
    mainProgram = "dagu";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
