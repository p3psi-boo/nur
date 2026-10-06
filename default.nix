# NUR 仓库入口（兼容性保留）
# 新的主入口通过 flake.nix 或 repo.nix

{
  pkgs ? import <nixpkgs> {
    config = import ./nix/config/nixpkgs.nix;
  },
  lib ? pkgs.lib,
}:

lib.filterAttrs (_: v: lib.isDerivation v) (import ./repo.nix { inherit pkgs lib; })
