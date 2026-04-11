{
  lib,
  stdenv,
  makeWrapper,
  nodejs,
  fetchurl,
}:

stdenv.mkDerivation {
  pname = "dbhub";
  version = "0.21.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@bytebase/dbhub/-/dbhub-0.21.2.tgz";
    hash = "sha256-0fix36x7wqawscn9vgs4djrrvims59rcsdb6zib2lqs04r237v3q";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Create output directory
    mkdir -p $out/lib/dbhub
    mkdir -p $out/bin

    # Extract package contents (npm tarballs have 'package' directory)
    tar -xzf "$src" -C $out/lib/dbhub --strip-components=1

    # Create wrapper script for the dbhub binary
    makeWrapper ${nodejs}/bin/node $out/bin/dbhub \
      --add-flags "$out/lib/dbhub/dist/index.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Zero-dependency, token-efficient database MCP server for PostgreSQL, MySQL, SQL Server, MariaDB, SQLite";
    homepage = "https://github.com/bytebase/dbhub";
    license = licenses.mit;
    mainProgram = "dbhub";
    platforms = platforms.unix;
    sourceProvenance = [ sourceTypes.fromSource ];
  };
}
