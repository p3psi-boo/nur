{
  pkgs ? import <nixpkgs> {
    config = import ./nixpkgs.nix;
  },
  lib ? pkgs.lib,
}:

let
  repo = import ../../repo.nix { inherit pkgs lib; };
in
lib.filterAttrs (_: v: lib.isDerivation v && lib.meta.availableOn pkgs.stdenv.hostPlatform v) repo
