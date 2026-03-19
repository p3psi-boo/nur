# Python UV toolchain overlay
# Exposes uv2nix, pyproject-nix, and our custom uv-builder
inputs: final: prev:

let
  inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
in

{
  # Expose uv2nix library
  uv2nix-lib = uv2nix.lib.override {
    pkgs = final;
  };

  # Expose pyproject-nix library
  pyproject-nix-lib = pyproject-nix.lib.override {
    pkgs = final;
  };

  # Expose our custom uv-builder
  uv-builder = final.callPackage ./mods/python/uv-builder.nix {
    inherit uv2nix pyproject-nix pyproject-build-systems;
  };
}
