{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "1.0.33";

  sources = {
    x86_64-linux = {
      file = "qoderclicn-linux-x64-baseline.tar.gz";
      hash = "sha256-EUe4SFd28LotcuDou0AV7Dx+qTFTLYeBxDpI0ZKo7qc=";
    };
    aarch64-linux = {
      file = "qoderclicn-linux-arm64.tar.gz";
      hash = "sha256-fYVYlGLtix3ovW9uAkXOura8gi+I3pqsWWB4cBomk14=";
    };
    x86_64-darwin = {
      file = "qoderclicn-darwin-x64.tar.gz";
      hash = "sha256-VVpopkf+zcpVDJxAneyC6rPbFFnmou+jof1MZKkADs8=";
    };
    aarch64-darwin = {
      file = "qoderclicn-darwin-arm64.tar.gz";
      hash = "sha256-B/9GdOZ+zm59ceFLisPi7GqlBxcOW8BuWnpruhm/kps=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "qoderclicn: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "qoderclicn";
  inherit version;

  src = fetchurl {
    url = "https://static.qoder.com.cn/qoder-cli-cn/releases/${version}/${source.file}";
    inherit (source) hash;
  };

  unpackPhase = ''
    runHook preUnpack
    tar -xzf $src
    runHook postUnpack
  '';

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    stdenv.cc.libc
  ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 qoderclicn $out/bin/qoderclicn
    runHook postInstall
  '';

  meta = with lib; {
    description = "Qoder CLI China distribution";
    homepage = "https://qoder.com.cn";
    downloadPage = "https://static.qoder.com.cn/qoder-cli-cn/channels/manifest.json";
    license = licenses.unfree;
    mainProgram = "qoderclicn";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
