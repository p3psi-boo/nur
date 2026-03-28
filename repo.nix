# NUR 仓库内的包定义
# 返回标准的包属性集，便于被 default.nix / overlay.nix / flake.nix 复用。

{
  pkgs,
  lib ? pkgs.lib,
  pkgsDir ? ./pkgs,
  generatedPath ? ./_sources/generated.nix,
}:
let
  entries = builtins.readDir pkgsDir;
  publicPackageNames = builtins.filter (
    name: entries.${name} == "directory" && builtins.pathExists (pkgsDir + "/${name}/default.nix")
  ) (builtins.attrNames entries);

  nurLib = import ./lib { inherit pkgs; };

  generatedSources = import generatedPath {
    inherit (pkgs)
      fetchgit
      fetchurl
      fetchFromGitHub
      dockerTools
      ;
  };

  extraArgsFor = pkgName:
    let
      metaPath = "${pkgsDir}/${pkgName}/meta.nix";
      hasMeta = builtins.pathExists metaPath;
      meta = if hasMeta then import metaPath else { };
      packageSpecificArgs = if meta ? extraArgs then meta.extraArgs pkgs else { };
      generatedArgs =
        if builtins.hasAttr pkgName generatedSources then { generated = generatedSources; } else { };
    in
    packageSpecificArgs // generatedArgs // { inherit nurLib; };
in
builtins.listToAttrs (
  map (
    pkgName:
    {
      name = pkgName;
      value = pkgs.callPackage (pkgsDir + "/${pkgName}") (extraArgsFor pkgName);
    }
  ) publicPackageNames
)
