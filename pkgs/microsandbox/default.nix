{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, openssl
}:

stdenv.mkDerivation rec {
  pname = "microsandbox";
  version = "0.2.6";

  src = fetchurl {
    url = "https://github.com/zerocore-ai/microsandbox/releases/download/microsandbox-v${version}/microsandbox-${version}-linux-x86_64.tar.gz";
    hash = "sha256-OX0+xpRjqZCjP6M4zuaZP0EqcoIpl6XiSg8oC/LafKo=";
  };

  sourceRoot = "microsandbox-${version}-linux-x86_64";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    openssl
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib"

    install -m755 msb msbrun msbserver msx msi msr "$out/bin/"
    install -m755 libkrun.so.1 libkrunfw.so.4 "$out/lib/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Easy, hardware-isolated execution of untrusted user/AI code";
    homepage = "https://github.com/zerocore-ai/microsandbox";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    mainProgram = "msb";
    platforms = [ "x86_64-linux" ];
  };
}
