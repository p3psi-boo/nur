# 共享的 Rust 构建优化配置
# 参考：docs/min-sized-rust.md
#
# 使用方法：
#   rustPlatform.buildRustPackage (rec {
#     # ... 其他配置 ...
#   } // rustOptimizedEnv)

{
  # Rust 二进制大小优化环境变量
  # 预计可减少 20-50% 的二进制体积
  rustOptimizedEnv = {
    # 禁用增量编译（减少构建产物）
    CARGO_BUILD_INCREMENTAL = "false";

    # 剥离符号表
    CARGO_PROFILE_RELEASE_STRIP = "symbols";

    # 优化级别：z = 优化体积
    CARGO_PROFILE_RELEASE_OPT_LEVEL = "z";

    # 启用链接时优化（LTO）
    CARGO_PROFILE_RELEASE_LTO = "true";

    # 减少代码生成单元（提高优化效果）
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";

    # panic 时直接 abort（减少展开代码）
    CARGO_PROFILE_RELEASE_PANIC = "abort";
  };
}
