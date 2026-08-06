{ appimageTools
, fetchurl
, lib
, xvfb-run
}:

let
  pname = "orca";
  version = "1.4.173";

  # Orca 官方 AppImage（Electron + Chromium），x86_64
  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    sha256 = "sha256-+pAiq3aewtqNTPpj34F8tUtIg2D81Edc+Yxa1Pb8dUQ=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # headless server 需要 Xvfb（无 DISPLAY 时 Orca 自动启动，需在 PATH 中找到）
  extraPkgs = ps: with ps; [
    xvfb-run
  ];

  meta = with lib; {
    description = "Orca AI coding assistant runtime (headless server)";
    homepage = "https://github.com/stablyai/orca";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "orca";
  };
}