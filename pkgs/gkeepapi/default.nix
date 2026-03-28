{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  flit-core,
  gpsoauth,
  future,
}:

buildPythonPackage (finalAttrs: {
  pname = "gkeepapi";
  version = "0.9.8-unstable-2024-01-15";

  src = fetchFromGitHub {
    owner = "kiwiz";
    repo = "gkeepapi";
    rev = "1a94b25c18a7abfdc23d1412091129cd63652877";
    hash = "sha256-3NT6GFVcN4HDPbcJAmino0FXmyoohZWl/kQqFzJTnbw=";
  };

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
