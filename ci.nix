{
  pkgs ? import <nixpkgs> {
    config = import ./nixpkgs-config.nix;
  },
  lib ? pkgs.lib,
}:
import ./default.nix { inherit pkgs lib; }
