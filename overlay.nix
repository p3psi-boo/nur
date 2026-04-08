# NUR 主 Overlay 入口（兼容性保留）
# 整合所有子 overlay：本仓库包、Python UV、Python 包、AOCC

{ inputs }:

final: prev:

let
  lib = prev.lib;
  pkgsDir = ./pkgs;
  generatedPath = ./_sources/generated.nix;

  # 加载 nvfetcher 生成的源信息
  generatedSources = import generatedPath {
    inherit (prev)
      fetchgit
      fetchurl
      fetchFromGitHub
      dockerTools
      ;
  };

  # 辅助函数：计算包需要的额外参数
  extraArgsFor = pkgName:
    let
      metaPath = "${pkgsDir}/${pkgName}/meta.nix";
      hasMeta = builtins.pathExists metaPath;
      meta = if hasMeta then import metaPath else { };
      packageSpecificArgs = if meta ? extraArgs then meta.extraArgs prev else { };
      generatedArgs =
        if builtins.hasAttr pkgName generatedSources then { generated = generatedSources; } else { };
    in
    packageSpecificArgs // generatedArgs;

  # 本仓库的包发现（非内核模块）
  entries = builtins.readDir pkgsDir;
  publicPackageNames = builtins.filter (
    name:
    entries.${name} == "directory"
    && builtins.pathExists (pkgsDir + "/${name}/default.nix")
    && name != "focaltech-spi"  # 内核模块单独处理
  ) (builtins.attrNames entries);

  repoOverlay = lib.listToAttrs (
    map (
      pkgName:
      {
        name = pkgName;
        value = prev.callPackage (pkgsDir + "/${pkgName}") (extraArgsFor pkgName);
      }
    ) publicPackageNames
  );

  # Focaltech SPI 内核模块构建函数 - 需要针对特定内核版本构建
  focaltech-spi-for = kernel:
    let
      sourceInfo = generatedSources.focaltech-spi;
    in
    prev.stdenv.mkDerivation {
      pname = "focaltech-spi-${kernel.modDirVersion}";
      version = "1.0.3-unstable-${sourceInfo.date}";

      src = sourceInfo.src;

      makeFlags = [
        "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      ];

      installPhase = ''
        runHook preInstall
        xz focal_spi.ko
        install -D focal_spi.ko.xz \
          $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/spi/focal_spi.ko.xz
        runHook postInstall
      '';

      meta = with lib; {
        description = "Focaltech fingerprint reader SPI driver (FTE3600/4800/6600/6900)";
        license = licenses.gpl2Only;
        platforms = platforms.linux;
      };
    };

  # Python UV 工具链
  inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
  pythonUvOverlay = {
    uv2nix-lib = uv2nix.lib.override { pkgs = prev; };
    pyproject-nix-lib = pyproject-nix.lib.override { pkgs = prev; };
    uv-builder = prev.callPackage ./mods/python/uv-builder.nix {
      inherit uv2nix pyproject-nix pyproject-build-systems;
    };
  };

  # Python 包（legacy）
  pythonPackagesOverlay = import ./python-packages final prev;

  # AOCC 编译器
  aoccOverlay = import ./nix/overlays/aocc.nix final prev;
in

repoOverlay
// pythonUvOverlay
// pythonPackagesOverlay
// aoccOverlay
// {
  # 导出 focaltech-spi 构建函数（默认使用当前内核）
  focaltech-spi = focaltech-spi-for prev.linuxPackages.kernel;

  # 为所有内核包集合添加 focaltech-spi
  linuxPackages = prev.linuxPackages // {
    focaltech-spi = focaltech-spi-for prev.linuxPackages.kernel;
  };
  linuxPackages_latest = prev.linuxPackages_latest // {
    focaltech-spi = focaltech-spi-for prev.linuxPackages_latest.kernel;
  };
  linuxPackages_zen = prev.linuxPackages_zen // {
    focaltech-spi = focaltech-spi-for prev.linuxPackages_zen.kernel;
  };
  linuxPackages_lqx = prev.linuxPackages_lqx // {
    focaltech-spi = focaltech-spi-for prev.linuxPackages_lqx.kernel;
  };
  linuxPackages_hardened = prev.linuxPackages_hardened // {
    focaltech-spi = focaltech-spi-for prev.linuxPackages_hardened.kernel;
  };
  linuxPackages_rt = prev.linuxPackages_rt // {
    focaltech-spi = focaltech-spi-for prev.linuxPackages_rt.kernel;
  };
}
