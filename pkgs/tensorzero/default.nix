{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  openssl,
}:

let
  sourceInfo = generated.tensorzero;
in
rustPlatform.buildRustPackage rec {
  pname = "tensorzero";
  version = sourceInfo.version;

  src = sourceInfo.src;

  # Cargo.toml is in the crates/ subdirectory
  cargoRoot = "crates";
  buildAndTestSubdir = cargoRoot;

  # Use cargoHash - will be computed on first build
  cargoHash = "sha256-I12qfvjBLpGB4dM0yhZlEaNCkX6pFmYQc20+Kk8TA5U=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  # Build only the gateway binary
  cargoBuildFlags = [ "-p gateway" ];

  # Optimize for binary size (see docs/min-sized-rust.md)
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "z";
  CARGO_PROFILE_RELEASE_LTO = "true";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_PANIC = "abort";

  # Strip all symbols (not just debug symbols)
  stripAllList = [ "bin" ];

  doCheck = false;  # Tests require external services

  meta = with lib; {
    description = "Open-source LLMOps platform - LLM gateway, observability, evaluation, optimization";
    homepage = "https://www.tensorzero.com";
    changelog = "https://github.com/tensorzero/tensorzero/releases/tag/${version}";
    license = licenses.asl20;
    mainProgram = "gateway";
    platforms = platforms.linux ++ platforms.darwin;
  };
}