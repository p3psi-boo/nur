# grok2api - Grok2API built with FastAPI
# https://github.com/chenyme/grok2api
# Includes PR #406 cherry-pick: fix SuperGrok multi-agent model empty response
{
  lib,
  stdenv,
  uv-builder,
  makeWrapper,
  generated,  # Required by repo.nix
}:

let
  # PR #406 commit: Fix SuperGrok multi-agent model empty response
  # https://github.com/chenyme/grok2api/pull/406
  # Using fork branch: Huan-zhaojun/grok2api@705996585663085008709754ea6342aea0a8d22b
  version = "1.6.2";

  # Custom src with PR#406 applied
  src = builtins.fetchGit {
    url = "https://github.com/Huan-zhaojun/grok2api.git";
    ref = "refs/heads/fix/supergrok-multiagent";
    rev = "705996585663085008709754ea6342aea0a8d22b";
  };

  # Python environment with all dependencies
  pythonEnv = uv-builder.buildUvPackage {
    pname = "grok2api-python";
    inherit version;
    lockFile = "${src}/uv.lock";
    bins = [ "python" "python3" "uvicorn" "granian" ];
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

    # Create the grok2api wrapper script
    cat > $out/bin/grok2api << 'EOF'
    #!/usr/bin/env bash
    set -e

    # Default environment variables
    export SERVER_HOST="''${SERVER_HOST:-0.0.0.0}"
    export SERVER_PORT="''${SERVER_PORT:-8000}"
    export SERVER_WORKERS="''${SERVER_WORKERS:-1}"
    export LOG_LEVEL="''${LOG_LEVEL:-INFO}"
    export DATA_DIR="''${DATA_DIR:-''$PWD/data}"

    # Ensure data directory exists
    mkdir -p "''$DATA_DIR"

    # Change to source directory and run
    cd @src@
    exec @python@ -m granian main:app \
      --interface asgi \
      --host "''$SERVER_HOST" \
      --port "''$SERVER_PORT" \
      --workers "''$SERVER_WORKERS" \
      --log-level "''${LOG_LEVEL,,}" \
      "''$@"
    EOF

    # Substitute actual paths
    substituteInPlace $out/bin/grok2api \
      --subst-var-by src "${src}" \
      --subst-var-by python "${pythonEnv}/bin/python3"

    chmod +x $out/bin/grok2api

    # Wrap the script to set PYTHONPATH
    wrapProgram $out/bin/grok2api \
      --prefix PYTHONPATH : "${pythonEnv}/lib/python3.13/site-packages:${src}"
  '';

  meta = {
    description = "Grok2API with PR#406: SuperGrok multi-agent fix (FastAPI-based Grok API)";
    homepage = "https://github.com/chenyme/grok2api";
    license = lib.licenses.mit;
    mainProgram = "grok2api";
  };
}
