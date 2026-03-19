{
  generated,
  lib,
  python3Packages,
}:

let
  sourceInfo = generated.gac;
  py = python3Packages;
in
py.buildPythonApplication {
  pname = "gac";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  pyproject = true;

  nativeBuildInputs = [
    py.hatchling
    py.packaging
  ];

  propagatedBuildInputs = [
    py.httpx
    py.httpcore
    py.tiktoken
    py.pydantic
    py."python-dotenv"
    py.click
    py.questionary
    py.rich
    py."prompt-toolkit"
  ];

  doCheck = false;

  pythonImportsCheck = [ "gac" ];

  meta = {
    description = "LLM-powered Git commit message generator with multi-provider support";
    homepage = "https://github.com/cellwebb/gac";
    changelog = "https://github.com/cellwebb/gac/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "gac";
  };
}
