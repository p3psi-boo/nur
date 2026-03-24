# Package metadata for 'ut'
# Declares extra arguments needed by this package's default.nix

{
  # Function that returns extra arguments for callPackage
  # Takes the final package set and returns an attribute set
  extraArgs = pkgs: {
    inherit (pkgs) lib;
    buildRustPackage = pkgs.rustPlatform.buildRustPackage;
  };
}
