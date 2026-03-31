# grok2api - Grok2API built with FastAPI
# https://github.com/chenyme/grok2api
{
  lib,
  stdenv,
  uv-builder,
  makeWrapper,
  generated,
}:

let
  inherit (generated.grok2api) version src;
  
  # Build the Python environment using uv2nix
  pythonEnv = uv-builder.buildUvPackage {
    pname = "grok2api-env";
    inherit version;
    lockFile = "${src}/uv.lock";
    bins = [ ];
    meta = {
      description = "Grok2API Python environment";
    };
  };
in

stdenv.mkDerivation {
  pname = "grok2api";
  inherit version src;

  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    
    # Create the grok2api wrapper script
    # Use double quotes for heredoc to allow $src expansion
    # Escape $ for runtime variables with \$
    cat > $out/bin/grok2api << EOF
    #!/usr/bin/env bash
    set -e
    
    # Default environment variables
    export SERVER_HOST="\''${SERVER_HOST:-0.0.0.0}"
    export SERVER_PORT="\''${SERVER_PORT:-8000}"
    export SERVER_WORKERS="\''${SERVER_WORKERS:-1}"
    export LOG_LEVEL="\''${LOG_LEVEL:-INFO}"
    export DATA_DIR="\''${DATA_DIR:-\$PWD/data}"
    
    # Ensure data directory exists
    mkdir -p "\$DATA_DIR"
    
    # Change to source directory and run
    cd $src
    exec ${pythonEnv}/bin/python -m uvicorn main:app \\
      --host "\$SERVER_HOST" \\
      --port "\$SERVER_PORT" \\
      --workers "\$SERVER_WORKERS" \\
      --log-level "\''${LOG_LEVEL,,}" \\
      "\$@"
    EOF
    
    chmod +x $out/bin/grok2api
    
    # Wrap the script to set proper environment
    wrapProgram $out/bin/grok2api
  '';

  meta = {
    description = "Grok2API rebuilt with FastAPI, fully aligned with the latest web call format";
    homepage = "https://github.com/chenyme/grok2api";
    license = lib.licenses.mit;
    mainProgram = "grok2api";
  };
}
