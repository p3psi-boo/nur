{
  lib,
  buildPythonApplication,
  generated,
  gkeepapi,
  click,
  fetchFromGitHub ? null,  # auto-passed by repo.nix, not used
}:

let
  sourceInfo = generated.gkeep;
in
buildPythonApplication {
  pname = "gkeep";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  format = "setuptools";

  patches = [
    ./patches/remove-pip-import.patch
  ];

  propagatedBuildInputs = [
    gkeepapi
    click
  ];

  doCheck = false;

  pythonImportsCheck = [ "google_keep_tasks" ];

  meta = {
    description = "Google Keep command line interface";
    homepage = "https://github.com/Nekmo/gkeep";
    license = lib.licenses.mit;
    mainProgram = "gkeep";
  };
}
