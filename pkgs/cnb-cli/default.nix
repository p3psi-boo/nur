{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "1.15.20";

  platforms = {
    x86_64-linux = {
      file = "cnb-linux-x64";
      hash = "sha256-O9YCut1A86M8v25cjU1oBqaq9kMMTA3+LJ/1ZsPrlag=";
    };
    aarch64-linux = {
      file = "cnb-linux-arm64";
      hash = "sha256-eISEKipZhXdGBQGlLhmzwJwWkikijrc1EL5/0RpgNZ4=";
    };
    x86_64-darwin = {
      file = "cnb-darwin-x64";
      hash = "sha256-VRFuSsQlQRRMyx7kZA6gsB7yyMH1PiSkyKtslzk+5iU=";
    };
    aarch64-darwin = {
      file = "cnb-darwin-arm64";
      hash = "sha256-X6xsMyai+8xDaRqTjQ+Cshxe3DxineA+UXwlWajStKA=";
    };
  };

  platform =
    platforms.${stdenv.hostPlatform.system}
      or (throw "Unsupported platform for cnb-cli: ${stdenv.hostPlatform.system}");
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
