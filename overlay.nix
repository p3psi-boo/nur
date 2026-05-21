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
  extraArgsFor =
    pkgName:
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
    map (pkgName: {
      name = pkgName;
      value = prev.callPackage (pkgsDir + "/${pkgName}") (extraArgsFor pkgName);
    }) publicPackageNames
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

  # ntfy-sh Darwin build fix: serve_unix.go excludes darwin from build tag
  # https://github.com/binwiederhier/ntfy/issues/1631
  ntfyDarwinFixOverlay = import ./overlays/ntfy-sh-darwin-fix.nix final prev;

  harlequinOverlay =
    let
      inherit (generatedSources) harlequin-mysql;
      harlequin-mysql-pkg = prev.python3Packages.buildPythonPackage {
        pname = "harlequin-mysql";
        version = prev.lib.removePrefix "v" harlequin-mysql.version;
        inherit (harlequin-mysql) src;
        pyproject = true;
        build-system = [ prev.python3Packages.hatchling ];
        dependencies = [
          prev.python3Packages.mysql-connector
        ]
        ++ prev.lib.optional (prev.python3Packages.pythonAtLeast "3.14") prev.python3Packages.duckdb;
        doCheck = false;
        pythonRemoveDeps = [ "harlequin" ];
        meta = {
          description = "Harlequin adapter for MySQL/MariaDB";
          homepage = "https://github.com/tconbeer/harlequin-mysql";
          license = prev.lib.licenses.mit;
        };
      };
    in
    {
      harlequin = prev.harlequin.overridePythonAttrs (oldAttrs: {
        dependencies = (oldAttrs.dependencies or [ ]) ++ [ harlequin-mysql-pkg ];
      });
    };
in

repoOverlay // pythonUvOverlay // pythonPackagesOverlay // aoccOverlay // harlequinOverlay // ntfyDarwinFixOverlay
