# Python package overrides
# Split into one extension file per package/override for easier maintenance.
{
  final,
  prev,
  generated,
  lib,
}:
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (import ./picosvg.nix { inherit final; })
    (import ./idapro.nix { inherit final; })
    (import ./cocoindex.nix { inherit final; })
    (import ./harlequin-mysql.nix { inherit generated lib; })
  ];
}
