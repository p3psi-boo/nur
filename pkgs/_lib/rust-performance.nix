# 共享的 Rust 运行时性能优化配置
# 以运行时性能为主（代码执行快），而非二进制体积或编译速度
#
# 与 rust-optimized.nix（体积优化 OPT_LEVEL=z）的区别：
# - rust-optimized.nix: 优化二进制体积（发布包更小）
# - rust-performance.nix: 优化运行时性能（代码执行更快）
#
# 使用方法：
#   rustPlatform.buildRustPackage (finalAttrs: {
#     # ... 其他配置 ...
#   } // (import ../_lib/rust-performance.nix).rustPerformanceEnv)

{
  # Rust 编译性能优化环境变量
  rustPerformanceEnv = {
    # 禁用增量编译（在 Nix 构建中无意义，反而增加开销）
    CARGO_BUILD_INCREMENTAL = "false";

    # 优化级别：3 = 最高运行时性能（编译较慢但运行快）
    CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";

    # 启用链接时优化（提高运行时性能）
    CARGO_PROFILE_RELEASE_LTO = "thin";  # thin LTO 比 full LTO 编译更快

    # 代码生成单元数量（1 = 最大优化，编译较慢但运行时更快）
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";

    # panic 时直接 abort（减少展开代码，编译更快）
    CARGO_PROFILE_RELEASE_PANIC = "abort";

    # 剥离符号表（减小体积，不影响编译速度）
    CARGO_PROFILE_RELEASE_STRIP = "symbols";
  };

  # 使用 mold 链接器的配置
  # 需要在 nativeBuildInputs 中添加 mold
  rustMoldLinkerEnv = {
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "mold";
    RUSTFLAGS = "-C link-arg=-fuse-ld=mold";
  };

  # 组合性能优化 + mold 链接器
  rustFastBuildEnv = {
    # 包含性能优化
    CARGO_BUILD_INCREMENTAL = "false";
    CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";
    CARGO_PROFILE_RELEASE_LTO = "thin";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "0";
    CARGO_PROFILE_RELEASE_PANIC = "abort";
    CARGO_PROFILE_RELEASE_STRIP = "symbols";
    
    # 包含 mold 链接器
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "mold";
    RUSTFLAGS = "-C link-arg=-fuse-ld=mold";
  };
}
