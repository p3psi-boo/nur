{
  lib,
  rustPlatform,
  generated,
  ...
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "ace-tool-rs";
  version = generated.ace-tool-rs.version;
  src = generated.ace-tool-rs.src;

  cargoHash = "sha256-G5c0fPRZQJ64PAp6JofjhR3Bx1VPqomT17DpW2xmVxc=";

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
    description = "A tool for working with ACE archives";
    homepage = "https://github.com/missdeer/ace-tool-rs";
    license = licenses.mit; # Assuming MIT, check actual license
    mainProgram = "ace-tool-rs";
  };
})
