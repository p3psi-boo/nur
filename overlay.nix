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

  # NUR 辅助库
  nurLib = import ./lib { pkgs = prev; };

  # 辅助函数：计算包需要的额外参数
  extraArgsFor = pkgName:
    let
      metaPath = "${pkgsDir}/${pkgName}/meta.nix";
      hasMeta = builtins.pathExists metaPath;
      meta = if hasMeta then import metaPath else { };
      packageSpecificArgs = if meta ? extraArgs then meta.extraArgs prev else { };
      generatedArgs =
        if builtins.hasAttr pkgName generatedSources then { generated = generatedSources; } else { };
      # 只在 meta.nix 中声明 useNurLib = true 时才传递 nurLib
      nurLibArgs = if meta ? useNurLib && meta.useNurLib then { inherit nurLib; } else { };
    in
    packageSpecificArgs // generatedArgs // nurLibArgs;

  # 本仓库的包发现
  entries = builtins.readDir pkgsDir;
  publicPackageNames = builtins.filter (
    name:
    entries.${name} == "directory"
    && builtins.pathExists (pkgsDir + "/${name}/default.nix")
    && name != "focaltech-spi"
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
