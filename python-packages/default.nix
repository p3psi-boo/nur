# Python package overrides
# Split into one extension file per package/override for easier maintenance.
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (import ./picosvg.nix { inherit final; })
    (import ./idapro.nix { inherit final; })
    (import ./cocoindex.nix { inherit final; })
  ];
}
