{
  lib,
  stdenv,
  fetchurl,
  generated,
}:

let
  sourceInfo = generated.bichon;
  version = sourceInfo.version;

  platform = stdenv.hostPlatform.system;
  urls = {
    x86_64-linux = {
      url = "https://github.com/rustmailer/bichon/releases/download/${version}/bichon-server-${version}-x86_64-unknown-linux-gnu.tar.gz";
      hash = "sha256-N7gYmFZV1W9eziEDdj0HpEm8GP2ybPMQ2MdbBqIANQc=";
    };
    aarch64-linux = {
      url = "https://github.com/rustmailer/bichon/releases/download/${version}/bichon-server-${version}-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-PyYqlG0klF3ZbV9hPz9VN9hgF3yINIOxg7akHgLBnOQ=";
    };
  };

  platformInfo = urls.${platform} or (throw "Unsupported platform: ${platform}");
in
stdenv.mkDerivation {
  pname = "bichon";
  inherit version;

  src = fetchurl {
    url = platformInfo.url;
    hash = platformInfo.hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -D -m755 bichon-cli $out/bin/bichon-cli
    install -D -m755 bichon-admin $out/bin/bichon-admin
    install -D -m755 bichon-server $out/bin/bichon-server
    runHook postInstall
  '';

  doCheck = false;

  meta = {
    description = "A lightweight, high-performance Rust email archiver with WebUI";
    homepage = "https://github.com/rustmailer/bichon";
    license = lib.licenses.agpl3Only;
    mainProgram = "bichon-server";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
