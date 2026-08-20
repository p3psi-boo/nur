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
      pkgPath = pkgsDir + "/${pkgName}";
      pkgArgs = builtins.functionArgs (import pkgPath);
      metaPath = "${pkgsDir}/${pkgName}/meta.nix";
      hasMeta = builtins.pathExists metaPath;
      meta = if hasMeta then import metaPath else { };
      packageSpecificArgs = if meta ? extraArgs then meta.extraArgs prev else { };
      generatedArgs =
        if pkgArgs ? generated then { generated = generatedSources; } else { };
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
    && name != "grok2api"
  ) (builtins.attrNames entries);

  # proxy.golang.org 在国内网络不可达，NUR 内 Go 包的 module 下载统一走 goproxy.cn。
  # 直接覆盖 prev.buildGoModule，使 repoOverlay 里的包（lazyssh /
  # ecloud-cloudpc-keepalive 等，它们本就需要本地构建）在 go mod vendor 阶段
  # 使用国内代理。nixpkgs 自身的 Go 包不受影响（走缓存，drv 不变）。
  # 注意：GOPROXY 在 go-modules 的 impureEnvVars 里，构建时会被 nix 清空，
  # 因此除 env 外还要在 preBuild hook 里显式 export。
  # buildGoModule 兼容两种调用方式：旧式 `buildGoModule { ... }`（属性集）
  # 与新式 `buildGoModule (finalAttrs: { ... })`（函数，lazyssh /
  # ecloud-computer-auto-boot / proxy-ns / web-search 使用）。`//` 只能合并
  # 属性集，函数入参需先 apply finalAttrs 拿到属性集后再合并。
  withGoProxyAttrs = args: args // {
    env = (args.env or { }) // { GOPROXY = "https://goproxy.cn,direct"; };
    preBuild =
      (args.preBuild or "")
      + "\nexport GOPROXY=https://goproxy.cn,direct\n";
  };
  withGoProxy =
    args:
    if builtins.isFunction args then
      (finalAttrs: withGoProxyAttrs (args finalAttrs))
    else
      withGoProxyAttrs args;
  nurPrev = prev // {
    buildGoModule =
      let
        orig = prev.buildGoModule;
      in
      # 保留 orig 的 .override/.overrideAttrs（octopus-api 用 .override { go = ...; }），
      # 同时把调用重定向到带 goproxy.cn 注入的版本。
      (builtins.removeAttrs orig [ "__functor" ])
      // {
        __functor = self: args: orig (withGoProxy args);
      };
  };

  repoOverlay = lib.listToAttrs (
    map (pkgName: {
      name = pkgName;
      value = (lib.callPackageWith (nurPrev // pythonUvOverlay)) (pkgsDir + "/${pkgName}") (extraArgsFor pkgName);
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
        # nixpkgs 的 mysql-connector-python 已升到 26.x，而 harlequin-mysql 上游
        # pyproject 仍约束 `<10`，导致 pythonRuntimeDepsCheckHook 误报不满足。
        # 运行时依赖已由 `dependencies` 显式声明，跳过该检查即可。
        dontCheckRuntimeDeps = true;
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

repoOverlay // pythonUvOverlay // pythonPackagesOverlay // harlequinOverlay
