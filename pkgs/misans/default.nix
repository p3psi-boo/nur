{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "misans";
  version = "1.0";

  src = fetchzip {
    url = "https://cdn.cnbj1.fds.api.mi-img.com/vipmlmodel/font/MiSans/MiSans.zip";
    stripRoot = false;
    hash = "sha256-sDVOF7wZ22qsPkoQjFYNjaB4TrDbbNk+a2oHr8KbA+o=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fonts/truetype
    find . \
      -path './__MACOSX*' -prune -o \
      -type f -name '*.ttf' \
      -exec install -m644 {} $out/share/fonts/truetype/ \;

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://hyperos.mi.com/font/zh/download/";
    description = "Free fonts developed by XiaoMi Corporation.";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
