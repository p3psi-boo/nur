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
import ./default.nix { inherit pkgs lib; }
