{
  lib,
  rustPlatform,
  generated,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cnb-cli";
  version = generated.cnb-cli.version;
  src = generated.cnb-cli.src;

  cargoHash = "sha256-m9BZmmwrLoz9VH1wUMJrB5eiGqXhzFjq52iA+GFfyrI=";

  # Optimize for runtime performance
  CARGO_BUILD_INCREMENTAL = "false";
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";
  CARGO_PROFILE_RELEASE_LTO = "thin";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "0";
  CARGO_PROFILE_RELEASE_PANIC = "abort";

  # Strip all symbols (not just debug symbols)
  stripAllList = [ "bin" ];

  meta = with lib; {
    description = "CNB CLI tool";
    homepage = "https://github.com/p3psi-boo/cnb-cli";
    license = licenses.mit;
    mainProgram = "cnb-cli";
  };
})
