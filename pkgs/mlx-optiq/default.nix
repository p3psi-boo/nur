{
  lib,
  python3Packages,
  generated,
}:

let
  sourceInfo = generated."mlx-optiq";
  py = python3Packages;
  coreDependencies = with py; [
    mlx
    mlx-lm
    numpy
    scipy
    huggingface-hub
    click
    psutil
  ];
  vlmDependencies = with py; [
    mlx-vlm
    pillow
  ];
in
py.buildPythonPackage {
  pname = "mlx-optiq";
  inherit (sourceInfo) version;

  src = sourceInfo.src;

  pyproject = true;

  build-system = with py; [
    setuptools
    wheel
  ];

  dependencies = coreDependencies ++ vlmDependencies;

  pythonImportsCheck = [
    "optiq"
    "optiq.serve"
    "optiq.responses_server"
    "optiq.anthropic_server"
    "optiq.runtime.engine"
  ];

  passthru = {
    withVlm = true;
    optional-dependencies = {
      vlm = vlmDependencies;
    };
  };

  meta = {
    description = "Mixed-precision quantization optimizer for LLMs on Apple Silicon";
    homepage = "https://mlx-optiq.com";
    changelog = "https://pypi.org/project/mlx-optiq/${sourceInfo.version}/";
    license = lib.licenses.mit;
    mainProgram = "optiq";
    platforms = [ "aarch64-darwin" ];
  };
}
