{
  lib,
  rustPlatform,
  fetchurl,
  stdenv,
  generated,
}:

let
  sourceInfo = generated.celld;

  # celld depends on the v8 crate (rusty_v8). Nix has no network at compile
  # time, so feed denoland's official prebuilt archive through the env vars
  # the crate's build script accepts (same mechanism nixpkgs uses for deno).
  # celld 0.4.1 pins rusty_v8 152.1.0 (Locker + Send Globals).
  v8Version = "152.1.0";
  v8ReleaseBase = "https://github.com/denoland/rusty_v8/releases/download/v${v8Version}";

  v8Archive = fetchurl {
    url = "${v8ReleaseBase}/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
    sha256 = "sha256-VrPZwer2AINF3rP3yWqtIhfpHGXYt4v+VQ9Sw6jbtQ8=";
  };

  v8Binding = fetchurl {
    url = "${v8ReleaseBase}/src_binding_release_x86_64-unknown-linux-gnu.rs";
    sha256 = "sha256-Pk1f7Nvg+YpgF+adfKglGad/sDLF615M2+zdPi7FGdU=";
  };
in
rustPlatform.buildRustPackage {
  pname = "celld";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  env = {
    RUSTY_V8_ARCHIVE = v8Archive;
    RUSTY_V8_SRC_BINDING_PATH = v8Binding;
  };

  # Tests exercise the standalone engine smoke path; the distributed protocol
  # conformance suite runs before each upstream release. Keep the build light.
  doCheck = false;

  meta = {
    description = "Self-hosted, distributed Durable Objects — run Cloudflare Workers and Durable Objects on your own machines";
    homepage = "https://github.com/denoland/celld";
    changelog = "https://github.com/denoland/celld/releases/tag/${sourceInfo.version}";
    license = lib.licenses.asl20;
    mainProgram = "celld";
    platforms = [ "x86_64-linux" ];
    broken = !stdenv.hostPlatform.isx86_64 || !stdenv.hostPlatform.isLinux;
  };
}
