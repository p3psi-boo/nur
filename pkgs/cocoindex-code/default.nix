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

    python - <<'PY'
from pathlib import Path

path = Path("src/cocoindex_code/client.py")
text = path.read_text()

text = text.replace("import os\n", "import os\nimport shutil\n", 1)

old = """def _find_ccc_executable() -> str | None:
    \"\"\"Find the ccc executable in PATH or the same directory as python.\"\"\"
    python_dir = Path(sys.executable).parent
    # On Windows the script is ccc.exe; on Unix it's just ccc
    names = [\"ccc.exe\", \"ccc\"] if sys.platform == \"win32\" else [\"ccc\"]
    for name in names:
        ccc = python_dir / name
        if ccc.exists():
            return str(ccc)
    return None
"""
new = """def _find_ccc_executable() -> str | None:
    \"\"\"Find the ccc launcher that carries the full runtime environment.\"\"\"
    argv0 = Path(sys.argv[0]).resolve()
    names = [\"ccc.exe\", \"ccc\"] if sys.platform == \"win32\" else [\"ccc\"]

    if argv0.name in names and argv0.exists():
        return str(argv0)

    for name in names:
        ccc = shutil.which(name)
        if ccc is not None:
            return ccc

    python_dir = Path(sys.executable).parent
    for name in names:
        ccc = python_dir / name
        if ccc.exists():
            return str(ccc)
    return None
"""

if old not in text:
    raise SystemExit("failed to find _find_ccc_executable() in src/cocoindex_code/client.py")

path.write_text(text.replace(old, new, 1))
PY
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
