{
  lib,
  stdenvNoCC,
  misans,
  nerdFontPatcher,
}:

stdenvNoCC.mkDerivation {
  pname = "misans-nerd";
  inherit (misans) version;

  dontUnpack = true;

  nativeBuildInputs = [ nerdFontPatcher ];

  installPhase = ''
    runHook preInstall

    install -d "$out/share/fonts/truetype"

    for font in ${misans}/share/fonts/truetype/*.ttf; do
      nerd-font-patcher \
        --complete \
        --variable-width-glyphs \
        --no-progressbars \
        --quiet \
        --outputdir "$out/share/fonts/truetype" \
        "$font"
    done

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://hyperos.mi.com/font/zh/download/";
    description = "MiSans patched with Nerd Font glyphs";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
