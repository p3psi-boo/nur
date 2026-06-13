# grok2api - Grok2API built with FastAPI (Runtime Performance Optimized)
# https://github.com/jiujiu532/grok2api
# Runtime optimizations for I/O-heavy workloads (API proxy to Grok)
{
  lib,
  stdenv,
  uv-builder,
  makeWrapper,
  generated,
}:

let
  inherit (generated.grok2api) src date;
  version = "0-unstable-${date}";

  pythonEnv = uv-builder.buildUvPackage {
    pname = "grok2api-python";
    version = "0.0.0";
    lockFile = "${src}/uv.lock";
    bins = [ "python" "python3" "uvicorn" ];
    meta = {
      description = "Grok2API Python environment";
    };
  };
in

stdenv.mkDerivation {
  pname = "grok2api";
  inherit version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin

    # Link all binaries from pythonEnv
    for bin in ${pythonEnv}/bin/*; do
      if [ -f "$bin" ] && [ -x "$bin" ]; then
        basename=$(basename "$bin")
        if [ ! -f "$out/bin/$basename" ]; then
          ln -s "$bin" "$out/bin/$basename"
        fi
      fi
    done

    # Create grok2api wrapper script
    # upstream main.py handles env vars (SERVER_HOST, SERVER_PORT, SERVER_WORKERS, LOG_LEVEL)
    # and calls uvicorn internally.
    cat > $out/bin/grok2api << 'EOF'
    #!/usr/bin/env bash
    set -e

    # Ensure data directory exists if set
    if [[ -n "''${DATA_DIR:-}" ]]; then
      mkdir -p "''$DATA_DIR"
    fi

    # Change to source directory
    cd @src@

    exec @python@ main.py "''$@"
    EOF

    substituteInPlace $out/bin/grok2api \
      --subst-var-by src "${src}" \
      --subst-var-by python "${pythonEnv}/bin/python3"

    chmod +x $out/bin/grok2api

    wrapProgram $out/bin/grok2api \
      --prefix PYTHONPATH : "${pythonEnv}/lib/python3.13/site-packages:${src}"
  '';

  passthru = {
    inherit src pythonEnv;
  };

  meta = {
    description = "Grok2API - FastAPI-based Grok API with runtime performance optimizations";
    homepage = "https://github.com/jiujiu532/grok2api";
    license = lib.licenses.mit;
    mainProgram = "grok2api";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
