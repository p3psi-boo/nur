{
  lib,
  rustPlatform,
  generated,
}:

let
  sourceInfo = generated.grok-search-rs;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "grok-search-rs";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  doCheck = false;

  meta = with lib; {
    description = "Rust MCP server for Grok web search and Tavily-backed source retrieval";
    homepage = "https://github.com/Episkey-G/GrokSearch-rs";
    license = licenses.mit;
    mainProgram = "grok-search-rs";
    platforms = platforms.unix;
  };
})
