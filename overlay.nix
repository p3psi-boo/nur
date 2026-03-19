# NUR overlay 入口
# 所有仓库内包定义都经由 ./repo.nix 统一生成。

{ inputs }:
final: prev:
let
  repoOverlay = import ./repo.nix {
    pkgs = final;
    lib = final.lib;
  };
  pythonUvOverlay = (import ./python-uv.nix inputs) final prev;
  pythonPackagesOverlay = import ./python-packages.nix final prev;
  aoccOverlay = import ./aocc-overlay.nix final prev;
in
repoOverlay
// pythonUvOverlay
// pythonPackagesOverlay
// aoccOverlay
