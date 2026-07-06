{
  lib,
  stdenv,
  rustPlatform,
  generated,
  pkg-config,
  openssl,
  curl,
  darwin,
  git,
  cacert,
}:

let
  sourceInfo = generated.pi-agent-rust;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "pi-agent-rust";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
    git
    cacert
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.apple_sdk_11_0.llvmPackages.libcxx
  ];

  buildInputs = [
    openssl
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    curl
  ];

  # Allow nightly features (portable_simd) on stable Rust 1.95
  RUSTC_BOOTSTRAP = 1;
  SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  doCheck = false;

  meta = with lib; {
    description = "High-performance AI coding agent CLI written in Rust with zero unsafe code";
    homepage = "https://github.com/Dicklesworthstone/pi_agent_rust";
    changelog = "https://github.com/Dicklesworthstone/pi_agent_rust/releases/tag/${sourceInfo.version}";
    license = licenses.mit;
    mainProgram = "pi";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
