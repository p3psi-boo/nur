{
  stdenv,
  lib,
  generated,
  postgresql,
  curl,
  lz4,
  clang,
  duckdb,
  substituteAll,
}:

let
  sourceInfo = generated.pg_duckdb;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "pg_duckdb";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  nativeBuildInputs = [
    postgresql.pg_config
    clang
    duckdb.dev
  ];

  buildInputs = [
    postgresql
    curl
    lz4
    duckdb
  ];

  postPatch = ''
        # Create third_party/duckdb directory structure and link to system DuckDB
        mkdir -p third_party/duckdb/src
        ln -s ${duckdb.dev}/include third_party/duckdb/src/include

    # Create build directory structure and link to system DuckDB library
    mkdir -p third_party/duckdb/build/release/src
    ln -s ${duckdb.lib}/lib/libduckdb.so third_party/duckdb/build/release/src/libduckdb.so

        # Create fake Makefile in third_party/duckdb to skip building DuckDB
        cat > third_party/duckdb/Makefile << 'EOF'
    .PHONY: release
    release:
    	@echo "Using system DuckDB library, skipping build"
    EOF

        # Create fake .git structure to satisfy Makefile's submodule check
        mkdir -p .git/modules/third_party/duckdb
        touch .git/modules/third_party/duckdb/HEAD
  '';

  makeFlags = [
    "USE_PGXS=1"
  ];

  installFlags = [
    "DESTDIR=$(out)"
  ];

  meta = {
    description = "DuckDB-powered Postgres for high performance analytics";
    homepage = "https://github.com/duckdb/pg_duckdb";
    changelog = "https://github.com/duckdb/pg_duckdb/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = postgresql.meta.platforms;
    maintainers = [ ];
    mainProgram = "pg_duckdb";
  };
})
