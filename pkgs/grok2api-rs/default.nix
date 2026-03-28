{
  lib,
  rustPlatform,
  generated,
  cmake,
  ninja,
  perl,
  pkg-config,
  git,
  zstd,
}:

let
  rustPerformance = import ../_lib/rust-performance.nix;
in
rustPlatform.buildRustPackage (
  finalAttrs: ({
    pname = "grok2api-rs";
    version = generated.grok2api-rs.version;
    src = generated.grok2api-rs.src;

    cargoLock = {
      lockFile = "${finalAttrs.src}/Cargo.lock";
    };

    nativeBuildInputs = [
      cmake
      ninja
      perl
      pkg-config
      git
      rustPlatform.bindgenHook
    ];

    buildInputs = [ zstd ];

    # `boring-sys2` needs cmake/ninja in PATH, but this package itself is built by Cargo.
    dontUseCmakeConfigure = true;
    dontUseNinjaBuild = true;
    dontUseNinjaCheck = true;
    dontUseNinjaInstall = true;

    doCheck = false;

    postInstall = ''
      install -Dm644 "${finalAttrs.src}/config.defaults.toml" "$out/share/grok2api-rs/config.defaults.toml"
    '';

    meta = with lib; {
      description = "OpenAI-compatible Grok gateway with an admin dashboard";
      homepage = "https://github.com/XeanYu/grok2api-rs";
      license = licenses.mit;
      mainProgram = "grok2api-rs";
      platforms = platforms.linux;
    };
  } // rustPerformance.rustPerformanceEnv)
)
