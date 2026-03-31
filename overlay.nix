# NUR 主 Overlay 入口（兼容性保留）
# 整合所有子 overlay：本仓库包、Python UV、Python 包、AOCC

{ inputs }:

final: prev:

let
  # 本仓库的包发现
  repoOverlay = import ./repo.nix { pkgs = final; lib = final.lib; };

  # Python UV 工具链
  inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
  pythonUvOverlay = {
    uv2nix-lib = uv2nix.lib.override { pkgs = final; };
    pyproject-nix-lib = pyproject-nix.lib.override { pkgs = final; };
    uv-builder = final.callPackage ./mods/python/uv-builder.nix {
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
