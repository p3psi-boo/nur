{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  openssl,
  sqlite,
  nurLib,
  ...
}:

rustPlatform.buildRustPackage (
  finalAttrs: {
    pname = "agsh";
    version = generated.agsh.version;
    src = generated.agsh.src;

    cargoLock = {
      lockFile = "${finalAttrs.src}/Cargo.lock";
    };

    nativeBuildInputs = [
      pkg-config
      rustPlatform.bindgenHook
    ];

    buildInputs = [
      openssl
      sqlite
    ];

    env = nurLib.rustPerformanceEnv;

    doCheck = false;

    meta = with lib; {
      description = "An agentic shell where you speak human, not bash";
      homepage = "https://github.com/k4yt3x/agsh";
      license = licenses.mit;
      mainProgram = "agsh";
      platforms = platforms.unix;
    };
  }
)
