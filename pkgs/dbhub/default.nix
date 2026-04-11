{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
}:

buildNpmPackage rec {
  pname = "dbhub";
  version = "0.21.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@bytebase/dbhub/-/dbhub-${version}.tgz";
    hash = "sha256-eOwzRCZAYypW/GY1zXIqusads2xEv50s01xhfroZPTo=";
  };
  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-ggqsoF4LiFrxtsinpANY6oTAzZJY9/xUYsgEOeJ3KFw=";
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/dbhub"

    install -d "$appDir" "$out/bin"
    cp -r dist package.json node_modules "$appDir/"

    makeWrapper ${nodejs}/bin/node "$out/bin/dbhub" \
      --add-flags "$appDir/dist/index.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Token-efficient database MCP server for PostgreSQL, MySQL, SQL Server, MariaDB, SQLite";
    homepage = "https://github.com/bytebase/dbhub";
    license = licenses.mit;
    mainProgram = "dbhub";
    platforms = platforms.unix;
  };
}
