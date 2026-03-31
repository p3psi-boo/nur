# grok2api - Grok2API built with FastAPI
# https://github.com/chenyme/grok2api
{
  lib,
  uv-builder,
  generated,
}:

let
  inherit (generated.grok2api) version src;
in

uv-builder.buildUvPackage {
  pname = "grok2api";
  inherit version;

  # Use the uv.lock from the source
  lockFile = "${src}/uv.lock";

  bins = [ ];

  meta = {
    description = "Grok2API rebuilt with FastAPI, fully aligned with the latest web call format";
    homepage = "https://github.com/chenyme/grok2api";
    license = lib.licenses.mit;
    mainProgram = "grok2api";
  };
}
