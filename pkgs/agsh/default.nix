{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  openssl,
  sqlite,
  ...
}:

let
  rustPerformance = import ../_lib/rust-performance.nix;
in
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

    # 项目本身已有 release 优化配置，使用 Nix 的共享性能优化
    env = rustPerformance.rustPerformanceEnv;

    # rusqlite 使用 bundled 特性，不需要系统 sqlite，但保留依赖以备后续调整
    # reqwest 使用 rustls-tls，不需要 native-tls

    doCheck = false; # 跳过测试，通常需要网络或特定环境

    meta = with lib; {
      description = "An agentic shell where you speak human, not bash";
      homepage = "https://github.com/k4yt3x/agsh";
      license = licenses.mit;
      mainProgram = "agsh";
      platforms = platforms.unix;
    };
  }
)
