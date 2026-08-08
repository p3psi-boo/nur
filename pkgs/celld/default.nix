{
  lib,
  rustPlatform,
  fetchurl,
  stdenv,
  generated,
}:

let
  sourceInfo = generated.celld;

  # celld depends on the v8 crate (rusty_v8), whose build script downloads a
  # prebuilt V8 static library + generated bindings at compile time. Nix builds
  # have no network access, so we feed the official prebuilt artifacts (published
  # by denoland as release assets for each rusty_v8 release) through the env
  # vars the v8 crate's build script supports (RUSTY_V8_ARCHIVE /
  # RUSTY_V8_SRC_BINDING_PATH) — same mechanism nixpkgs uses for deno.
  v8Version = "152.0.0";
  v8ReleaseBase = "https://github.com/denoland/rusty_v8/releases/download/v${v8Version}";

  prebuilt = {
    x86_64-linux = {
      archive = "librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
      archiveHash = "sha256-nS++EYCa01QTDVw3gmNqE89YaNptLAAtqIJ7hT01x+w=";
      bindingHash = "sha256-Pk1f7Nvg+YpgF+adfKglGad/sDLF615M2+zdPi7FGdU=";
    };
    aarch64-linux = {
      archive = "librusty_v8_release_aarch64-unknown-linux-gnu.a.gz";
      archiveHash = "sha256-pTVYAE1/5QIGX1ucQrUHl5MLMM42DokTeZ2+wK7upA8=";
      bindingHash = "sha256-Pk1f7Nvg+YpgF+adfKglGad/sDLF615M2+zdPi7FGdU=";
    };
    x86_64-darwin = {
      archive = "librusty_v8_release_x86_64-apple-darwin.a.gz";
      archiveHash = "sha256-9Q+MSeQP+Kb2aByNQ6p8wbMQFfghXTS5eQzoz/ynPuw=";
      bindingHash = "sha256-udVlLrylFesr9MLuSmVRslZxF7Wqcg9DDSAyYW3X47U=";
    };
    aarch64-darwin = {
      archive = "librusty_v8_release_aarch64-apple-darwin.a.gz";
      archiveHash = "sha256-q5Rw4GxkJlSae1lBIMTg8GAS5wEFzcOi9CGiv9YJqiA=";
      bindingHash = "sha256-udVlLrylFesr9MLuSmVRslZxF7Wqcg9DDSAyYW3X47U=";
    };
  };

  p = prebuilt.${stdenv.hostPlatform.system} or (throw "celld: unsupported system ${stdenv.hostPlatform.system}");

  v8Archive = fetchurl {
    url = "${v8ReleaseBase}/${p.archive}";
    sha256 = p.archiveHash;
  };

  v8Binding = fetchurl {
    url = "${v8ReleaseBase}/src_binding_release_${stdenv.hostPlatform.rust.rustcTarget}.rs";
    sha256 = p.bindingHash;
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
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

  meta = with lib; {
    description = "Self-hosted, distributed Durable Objects — run Cloudflare Workers and Durable Objects on your own machines";
    homepage = "https://github.com/denoland/celld";
    changelog = "https://github.com/denoland/celld/releases/tag/${sourceInfo.version}";
    license = licenses.asl20;
    mainProgram = "celld";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
})
