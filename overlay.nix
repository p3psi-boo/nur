# NUR overlay entrypoint: repo packages, Python UV toolchain.

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
      value = (lib.callPackageWith (prev // pythonUvOverlay)) (pkgsDir + "/${pkgName}") (extraArgsFor pkgName);
    }) publicPackageNames
  );

in

repoOverlay // pythonUvOverlay
