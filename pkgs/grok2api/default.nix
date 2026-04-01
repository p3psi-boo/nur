# grok2api - Grok2API built with FastAPI (Runtime Performance Optimized)
# https://github.com/JinchengGao-Infty/grok2api
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

    # Create optimized grok2api wrapper script
    cat > $out/bin/grok2api << 'EOF'
    #!/usr/bin/env bash
    set -e

    # ===== Basic Server Settings =====
    export SERVER_HOST="''${SERVER_HOST:-0.0.0.0}"
    export SERVER_PORT="''${SERVER_PORT:-8000}"
    export LOG_LEVEL="''${LOG_LEVEL:-INFO}"
    export DATA_DIR="''${DATA_DIR:-''$PWD/data}"
    
    # ===== Granian ASGI Server Tuning =====
    # Worker count: For I/O-bound apps like grok2api, can use more workers
    # Formula: min(CPU cores * 2, 16) for I/O bound workloads
    # Or use 1 worker with high blocking-threads if mostly async
    _cpu_cores=$(nproc 2>/dev/null || echo 1)
    export SERVER_WORKERS="''${SERVER_WORKERS:-$(( _cpu_cores > 8 ? 16 : _cpu_cores * 2 ))}"
    
    # Interface: asgi (std) or asginl (inline, slightly faster but less compatible)
    export GRANIAN_INTERFACE="''${GRANIAN_INTERFACE:-asgi}"
    
    # HTTP version: auto, 1, or 2
    export GRANIAN_HTTP="''${GRANIAN_HTTP:-1}"
    
    # WebSocket support: grok2api uses WebSocket for image generation
    export GRANIAN_WEBSOCKETS="''${GRANIAN_WEBSOCKETS:-true}"
    
    # Blocking threads: For sync operations in async handlers
    # Note: >1 only works with wsgi interface
    export GRANIAN_BLOCKING_THREADS="''${GRANIAN_BLOCKING_THREADS:-1}"
    
    # Connection backlog: Increase for high-traffic scenarios
    export GRANIAN_BACKLOG="''${GRANIAN_BACKLOG:-2048}"
    
    # ===== grok2api Internal Concurrency Tuning =====
    # These map to config.toml settings but can be set via env
    
    # Chat API concurrency (default 50)
    export CHAT_CONCURRENT="''${CHAT_CONCURRENT:-50}"
    
    # Image generation concurrency (default 100) 
    export IMAGE_CONCURRENT="''${IMAGE_CONCURRENT:-100}"
    export IMAGE_TIMEOUT="''${IMAGE_TIMEOUT:-60}"
    export IMAGE_STREAM_TIMEOUT="''${IMAGE_STREAM_TIMEOUT:-60}"
    
    # Video generation concurrency (default 100)
    export VIDEO_CONCURRENT="''${VIDEO_CONCURRENT:-100}"
    export VIDEO_TIMEOUT="''${VIDEO_TIMEOUT:-60}"
    
    # Token pool refresh settings
    export TOKEN_AUTO_REFRESH="''${TOKEN_AUTO_REFRESH:-true}"
    export TOKEN_REFRESH_INTERVAL="''${TOKEN_REFRESH_INTERVAL:-8}"
    export TOKEN_SUPER_REFRESH_INTERVAL="''${TOKEN_SUPER_REFRESH_INTERVAL:-2}"
    
    # Connection pool tuning for external storage (redis/mysql/pgsql)
    # If using external storage, tune these for better performance
    export STORAGE_POOL_SIZE="''${STORAGE_POOL_SIZE:-10}"
    export STORAGE_MAX_OVERFLOW="''${STORAGE_MAX_OVERFLOW:-20}"
    
    # ===== Python Runtime Optimizations =====
    # Disable bytecode writing for faster startup in containerized env
    export PYTHONDONTWRITEBYTECODE=1
    # Line buffering for logs
    export PYTHONUNBUFFERED=1
    # Optimize Python memory allocator for small objects
    export PYTHONMALLOC= pymalloc
    
    # ===== HTTP Client Tuning (for requests to Grok API) =====
    # Connection pool size for outbound HTTP requests
    export HTTP_POOL_SIZE="''${HTTP_POOL_SIZE:-100}"
    export HTTP_KEEPALIVE="''${HTTP_KEEPALIVE:-true}"
    export HTTP_TIMEOUT="''${HTTP_TIMEOUT:-60}"

    # Ensure data directory exists
    mkdir -p "''$DATA_DIR"

    # Change to source directory
    cd @src@
    
    # Build granian args
    GRANIAN_ARGS=(
      --interface "$GRANIAN_INTERFACE"
      --host "$SERVER_HOST"
      --port "$SERVER_PORT"
      --workers "$SERVER_WORKERS"
      --log-level "''${LOG_LEVEL,,}"
      --http "$GRANIAN_HTTP"
      --backlog "$GRANIAN_BACKLOG"
      --blocking-threads "$GRANIAN_BLOCKING_THREADS"
    )
    
    # WebSocket flag
    if [[ "$GRANIAN_WEBSOCKETS" == "false" ]]; then
      GRANIAN_ARGS+=(--no-ws)
    fi
    
    # Optional: threading mode for CPU-bound work (if needed)
    if [[ -n "''${GRANIAN_THREADS:-}" ]]; then
      GRANIAN_ARGS+=(--threads "$GRANIAN_THREADS")
    fi
    
    exec @python@ -m granian main:app "''${GRANIAN_ARGS[@]}" "''$@"
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
    description = "Grok2API (JinchengGao-Infty fork) - FastAPI-based Grok API with runtime performance optimizations";
    homepage = "https://github.com/JinchengGao-Infty/grok2api";
    license = lib.licenses.mit;
    mainProgram = "grok2api";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
