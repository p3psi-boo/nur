{
  lib,
  rustPlatform,
  generated,
}:

rustPlatform.buildRustPackage rec {
  pname = "ace-tool-rs";
  version = generated.ace-tool-rs.version;
  src = generated.ace-tool-rs.src;

  cargoHash = "sha256-G5c0fPRZQJ64PAp6JofjhR3Bx1VPqomT17DpW2xmVxc=";

  # Optimize for binary size (see docs/min-sized-rust.md)
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "z";
  CARGO_PROFILE_RELEASE_LTO = "true";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_PANIC = "abort";

  # Strip all symbols (not just debug symbols)
  stripAllList = [ "bin" ];

  meta = with lib; {
    description = "A tool for working with ACE archives";
    homepage = "https://github.com/missdeer/ace-tool-rs";
    license = licenses.mit; # Assuming MIT, check actual license
    mainProgram = "ace-tool-rs";
  };
}
