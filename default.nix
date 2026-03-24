{
  pkgs ? import <nixpkgs> {
    config = import ./nixpkgs-config.nix;
  },
  lib ? pkgs.lib,
}:
lib.filterAttrs (_: v: lib.isDerivation v) (import ./repo.nix { inherit pkgs lib; })
