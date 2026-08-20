# NUR overlay entrypoint: repo packages, Python UV toolchain, harlequin-mysql.

{ inputs }:

final: prev:

let
  lib = prev.lib;
  pkgsDir = ./pkgs;
  generatedPath = ./_sources/generated.nix;

  generatedSources = import generatedPath {
    inherit (prev)
      fetchgit
      fetchurl
      fetchFromGitHub
      dockerTools
      ;
  };

  nurLib = import ./lib { pkgs = prev; };

  extraArgsFor =
    pkgName:
    let
      pkgPath = pkgsDir + "/${pkgName}";
      pkgArgs = builtins.functionArgs (import pkgPath);
      metaPath = "${pkgsDir}/${pkgName}/meta.nix";
      hasMeta = builtins.pathExists metaPath;
      meta = if hasMeta then import metaPath else { };
      packageSpecificArgs = if meta ? extraArgs then meta.extraArgs prev else { };
      generatedArgs = if pkgArgs ? generated then { generated = generatedSources; } else { };
      nurLibArgs = if meta ? useNurLib && meta.useNurLib then { inherit nurLib; } else { };
    in
    packageSpecificArgs // generatedArgs // nurLibArgs;

  entries = builtins.readDir pkgsDir;
  publicPackageNames = builtins.filter (
    name: entries.${name} == "directory" && builtins.pathExists (pkgsDir + "/${name}/default.nix")
  ) (builtins.attrNames entries);

  # proxy.golang.org is often unreachable from CN; force goproxy.cn for NUR Go builds.
  # GOPROXY is in go-modules impureEnvVars and gets cleared by nix, so also export in preBuild.
  # buildGoModule accepts either an attrset or (finalAttrs: attrset).
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
      (builtins.removeAttrs orig [ "__functor" ])
      // {
        __functor = self: args: orig (withGoProxy args);
      };
  };

  inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
  pythonUvOverlay = {
    uv2nix-lib = uv2nix.lib.override { pkgs = prev; };
    pyproject-nix-lib = pyproject-nix.lib.override { pkgs = prev; };
    uv-builder = prev.callPackage ./mods/python/uv-builder.nix {
      inherit uv2nix pyproject-nix pyproject-build-systems;
    };
  };

  repoOverlay = lib.listToAttrs (
    map (pkgName: {
      name = pkgName;
      value = (lib.callPackageWith (nurPrev // pythonUvOverlay)) (pkgsDir + "/${pkgName}") (extraArgsFor pkgName);
    }) publicPackageNames
  );

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
        # nixpkgs mysql-connector-python is 26.x while upstream still constrains <10.
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

repoOverlay // pythonUvOverlay // harlequinOverlay
