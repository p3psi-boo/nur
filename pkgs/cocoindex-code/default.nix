{
  generated,
  lib,
  python3Packages,
}:

let
  sourceInfo = generated."cocoindex-code";
  py = python3Packages;
in
py.buildPythonApplication {
  pname = "cocoindex-code";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  pyproject = true;

  build-system = [
    py.hatchling
    py.hatch-vcs
  ];

  dependencies = [
    py.mcp
    py.cocoindex
    py.litellm
    py.sentence-transformers
    py.sqlite-vec
    py.pydantic
    py.numpy
    py.einops
    py.typer
    py.msgspec
    py.pathspec
    py.pyyaml
    py.rich
  ];

  pythonRelaxDeps = true;

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"cocoindex[litellm]==1.0.0a35",' '"cocoindex==1.0.0a35",'
  '';

  doCheck = false;

  pythonImportsCheck = [ "cocoindex_code" ];

  meta = with lib; {
    description = "AST-based semantic code search CLI built on CocoIndex";
    homepage = "https://github.com/cocoindex-io/cocoindex-code";
    changelog = "https://github.com/cocoindex-io/cocoindex-code/releases/tag/v${version}";
    license = licenses.asl20;
    mainProgram = "ccc";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
