{
  lib,
  buildPythonApplication,
  fetchFromGitHub,
  gkeepapi,
  click,
}:

buildPythonApplication {
  pname = "gkeep";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Nekmo";
    repo = "gkeep";
    rev = "d786fd6401becc2d9d55c23f290249ff03c3bc11";
    hash = "sha256-c1wE/lI3EqL3mjbrVJySBE//9JLdlZqekylKfeWLX3M=";
  };

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
