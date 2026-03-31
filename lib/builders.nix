# 构建辅助函数库
# 提供各类语言/框架的优化构建配置
# 原为 pkgs/_lib/ 的内容

{ lib }:

let
  # ============================================================================
  # Rust 构建优化
  # ============================================================================

  # 二进制体积优化 - 减少 20-50% 的二进制体积
  rustOptimizedEnv = {
    CARGO_BUILD_INCREMENTAL = "false";
    CARGO_PROFILE_RELEASE_STRIP = "symbols";
    CARGO_PROFILE_RELEASE_OPT_LEVEL = "z";
    CARGO_PROFILE_RELEASE_LTO = "true";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
    CARGO_PROFILE_RELEASE_PANIC = "abort";
  };

  # 运行时性能优化 - 最大化代码执行速度
  rustPerformanceEnv = {
    CARGO_BUILD_INCREMENTAL = "false";
    CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";
    CARGO_PROFILE_RELEASE_LTO = "thin";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
    CARGO_PROFILE_RELEASE_PANIC = "abort";
    CARGO_PROFILE_RELEASE_STRIP = "symbols";
  };

  # mold 链接器配置 - 加速链接阶段
  rustMoldLinkerEnv = {
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "mold";
    RUSTFLAGS = "-C link-arg=-fuse-ld=mold";
  };

  # 组合：性能优化 + mold 链接器
  rustFastBuildEnv = {
    CARGO_BUILD_INCREMENTAL = "false";
    CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";
    CARGO_PROFILE_RELEASE_LTO = "thin";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "0";
    CARGO_PROFILE_RELEASE_PANIC = "abort";
    CARGO_PROFILE_RELEASE_STRIP = "symbols";
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "mold";
    RUSTFLAGS = "-C link-arg=-fuse-ld=mold";
  };

  # 为 Rust 包选择合适的构建配置
  rustConfig = type:
    if type == "optimized" then rustOptimizedEnv
    else if type == "performance" then rustPerformanceEnv
    else if type == "fast" then rustFastBuildEnv
    else {};

in
{
  inherit
    rustOptimizedEnv
    rustPerformanceEnv
    rustMoldLinkerEnv
    rustFastBuildEnv
    rustConfig
    ;

  # 合并多个环境配置
  mergeEnvs = envs: lib.foldl' lib.mergeAttrs {} envs;
}
