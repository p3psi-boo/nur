# Package metadata for 'quicssh'
# Declares extra arguments needed by this package's default.nix

{
  # Function that returns extra arguments for callPackage
  # Takes the final package set and returns an attribute set
  extraArgs = pkgs: {
    go_1_24 = pkgs.go_1_24;
  };
}
