{
  lib,
  stdenvNoCC,
  php83,
  generated,
}:

let
  sourceInfo = generated.wallos;
  php = php83.buildEnv {
    extensions =
      { enabled, all }:
      enabled
      ++ (with all; [
        calendar
        curl
        dom
        gd
        intl
        mbstring
        openssl
        pdo_sqlite
        sqlite3
        zip
      ]);
  };
in
stdenvNoCC.mkDerivation {
  pname = "wallos";
  version = lib.removePrefix "v" sourceInfo.version;
  inherit (sourceInfo) src;

  nativeCheckInputs = [ php ];
  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    php tests/run.php
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r api db endpoints images includes libs migrations scripts styles webfonts "$out/"
    cp *.php robots.txt service-worker.js "$out/"
    mkdir -p "$out/.tmp"
    install -Dm644 LICENSE.md "$out/share/doc/wallos/LICENSE.md"
    runHook postInstall
  '';

  passthru = { inherit php; };

  meta = {
    description = "Self-hosted personal subscription tracker";
    homepage = "https://github.com/ellite/Wallos";
    changelog = "https://github.com/ellite/Wallos/releases/tag/${sourceInfo.version}";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
  };
}
