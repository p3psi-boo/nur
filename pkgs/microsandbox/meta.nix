# Package metadata for 'microsandbox'
# Declares extra arguments needed by this package's default.nix

{
  # Function that returns extra arguments for callPackage
  # Takes the final package set and returns an attribute set
  extraArgs = pkgs: {
    inherit (pkgs)
      lib
      stdenv
      fetchurl
      openssl
      autoPatchelfHook
      ;
  };
}
