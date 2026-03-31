{ pkgs }:

let
  lib = pkgs.lib;
  builders = import ./builders.nix { inherit lib; };
in

with lib; rec {
  # ============================================================================
  # 版本处理工具
  # ============================================================================

  # 移除版本号前缀的 'v'
  removeVPrefix = version: removePrefix "v" version;

  # 获取包的主要程序名
  getMainProgram = pname: pname;

  # ============================================================================
  # 源信息处理工具（nvfetcher 集成）
  # ============================================================================

  # 安全地获取 generated 源信息
  getGeneratedSource = pkgName: generated:
    if hasAttr pkgName generated
    then getAttr pkgName generated
    else throw "No generated source found for package '${pkgName}' in nvfetcher output. " +
               "Please check: 1) nvfetcher.toml has [${pkgName}] section, " +
               "2) Run nvfetcher to update _sources/generated.nix";

  # 检查包是否已配置 nvfetcher
  hasGeneratedSource = pkgName: generated: hasAttr pkgName generated;

  # 获取版本（优先从 generated，否则使用默认值）
  getVersion = generated: pkgName: defaultVersion:
    if hasGeneratedSource pkgName generated
    then (getGeneratedSource pkgName generated).version
    else defaultVersion;

  # ============================================================================
  # 构建工具（从 builders.nix 导出）
  # ============================================================================

  inherit (builders)
    rustOptimizedEnv
    rustPerformanceEnv
    rustMoldLinkerEnv
    rustFastBuildEnv
    rustConfig
    mergeEnvs
    ;

  # ============================================================================
  # 标准 meta 属性生成
  # ============================================================================

  mkMeta = { pname, version, description, homepage ? null, license, platforms ? platforms.unix, maintainers ? [] }:
    {
      inherit description license platforms maintainers;
      mainProgram = pname;
    } // (if homepage != null then { inherit homepage; } else {});

  # ============================================================================
  # 平台检测工具（Node.js/Rust 跨平台构建）
  # ============================================================================

  # Nix 平台转换为 NPM 平台标识
  nixToNpmOs = system: builtins.elemAt (splitString "-" system) 1;

  # Nix 架构转换为 NPM 架构标识
  nixToNpmCpu = system:
    let
      arch = builtins.elemAt (splitString "-" system) 0;
    in
    {
      x86_64 = "x64";
      aarch64 = "arm64";
      i686 = "ia32";
      armv7l = "arm";
    }.${arch} or arch;

  # Nix 平台转换为 Rust 目标三元组
  nixToRustTarget = system:
    let
      arch = builtins.elemAt (splitString "-" system) 0;
      os = builtins.elemAt (splitString "-" system) 1;
    in
    {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
      x86_64-darwin = "x86_64-apple-darwin";
      aarch64-darwin = "aarch64-apple-darwin";
    }.${system} or "${arch}-unknown-${os}-gnu";
}
