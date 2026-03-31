{
  pkgs ? import <nixpkgs> {
    config = import ./nixpkgs.nix;
  },
  lib ? pkgs.lib,
}:

let
  discovery = import ../../lib/discovery.nix { inherit pkgs lib; };
in
lib.filterAttrs (_: v: lib.isDerivation v) discovery
