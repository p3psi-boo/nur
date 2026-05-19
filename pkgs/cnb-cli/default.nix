{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "1.7.1";

  platforms = {
    x86_64-linux = {
      file = "cnb-linux-x64";
      hash = "sha256-NvAtFbCVDdm6+YtlVxjjqsc0R2yOn72Wpxjkk+Vs77c=";
    };
    aarch64-linux = {
      file = "cnb-linux-arm64";
      hash = "sha256-7M21QfTz4Gubd6Lxk82eVID1kpoNdoVcs2ZGbqA/5ms=";
    };
    x86_64-darwin = {
      file = "cnb-darwin-x64";
      hash = "sha256-lf9SCOSpWgtQhsbjg0P0VAQwID/PTYfqz0BsDV0cGEU=";
    };
    aarch64-darwin = {
      file = "cnb-darwin-arm64";
      hash = "sha256-zE/8scHQmkQbjMuqMDbeIPs3SVg8aumFfUyuD33Sluo=";
    };
  };

  platform = platforms.${stdenv.hostPlatform.system} or (throw "Unsupported platform for cnb-cli: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "cnb-cli";
  inherit version;

  src = fetchurl {
    url = "https://cnb.cool/cnb/skills/cnb-skill/-/releases/download/${version}/${platform.file}";
    inherit (platform) hash;
  };

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.libc
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 $src $out/bin/cnb
    runHook postInstall
  '';

  meta = with lib; {
    description = "CNB OpenAPI command-line tool";
    homepage = "https://cnb.cool/cnb/skills/cnb-skill";
    license = licenses.mit;
    mainProgram = "cnb";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
