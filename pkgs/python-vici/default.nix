{
  lib,
  python3Packages,
  strongswan,
}:
python3Packages.buildPythonPackage {
  pname = "vici";
  inherit (strongswan) version src;
  pyproject = true;
  # Reuse the exact daemon source locked by nixpkgs, not a second release pin.
  postUnpack = ''
    sourceRoot="$sourceRoot/src/libcharon/plugins/vici/python"
  '';
  postPatch = ''
    substitute setup.py.in setup.py --replace-fail '@EGG_VERSION@' '${strongswan.version}'
  '';
  build-system = [ python3Packages.setuptools ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];
  pytestFlags = [ "test" ];
  pythonImportsCheck = [ "vici" ];
  meta = {
    description = "Official Python bindings for strongSwan's VICI protocol";
    homepage = "https://docs.strongswan.org/docs/latest/plugins/vici.html";
    license = lib.licenses.mit;
  };
}
