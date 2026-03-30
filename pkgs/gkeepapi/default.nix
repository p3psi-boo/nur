{
  lib,
  buildPythonPackage,
  generated,
  flit-core,
  gpsoauth,
  future,
  fetchFromGitHub ? null,  # auto-passed by repo.nix, not used
}:

let
  sourceInfo = generated.gkeepapi;
in
buildPythonPackage (finalAttrs: {
  pname = "gkeepapi";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  pyproject = true;

  build-system = [
    flit-core
  ];

  propagatedBuildInputs = [
    gpsoauth
    future
  ];

  doCheck = false;

  pythonImportsCheck = [ "gkeepapi" ];

  meta = {
    description = "An unofficial client for the Google Keep API";
    homepage = "https://github.com/kiwiz/gkeepapi";
    license = lib.licenses.mit;
    mainProgram = "gkeepapi";
  };
})
