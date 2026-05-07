{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "misans";
  version = "1.0";

  src = fetchzip {
    url = "https://hyperos.mi.com/font-download/MiSans.zip";
    stripRoot = false;
    hash = "sha256-MH4t7oXDUiH1TAm0xKa0AENmB1zoedd8X5BcQFNw8GM=";
  };

  # only extract the variable font because everything else is a duplicate
  installPhase = ''
    runHook preInstall

    install -Dm644 MiSans/ttf/*.ttf -t $out/share/fonts/truetype

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://hyperos.mi.com/font/zh/download/";
    description = "Free fonts developed by XiaoMi Corporation.";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
