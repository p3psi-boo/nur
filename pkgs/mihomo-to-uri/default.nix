{
  lib,
  buildNpmPackage,
  nodejs,
  makeWrapper,
  generated,
}:

let
  sourceInfo = generated.mihomo-to-uri;
  version = "0-unstable-${sourceInfo.date}";
in
buildNpmPackage {
  pname = "mihomo-to-uri";
  inherit version;
  src = sourceInfo.src;

  npmDepsHash = "sha256-4Kwd8vfZA1wxVTAEZugEPdNTy0YD2KYHLfLYjsHJ+88=";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/mihomo-to-uri"
    install -d "$appDir" "$out/bin"

    cp -r dist "$appDir/"
    cp -r node_modules "$appDir/"
    cp package.json "$appDir/"

    makeWrapper ${nodejs}/bin/node "$out/bin/mihomo-to-uri" \
      --add-flags "$appDir/dist/index.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Convert mihomo/Clash proxy config to plain-text URI";
    homepage = "https://github.com/p3psi-boo/mihomo-to-uri";
    license = licenses.mit;
    mainProgram = "mihomo-to-uri";
    platforms = platforms.unix;
  };
}
