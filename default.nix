{
  pkgs ? import <nixpkgs> {
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  },
  lib ? pkgs.lib,
}:
lib.filterAttrs (_: v: lib.isDerivation v) (import ./repo.nix { inherit pkgs lib; })
