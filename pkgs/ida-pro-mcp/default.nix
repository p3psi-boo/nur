{
  generated,
  lib,
  python3Packages,
}:

let
  sourceInfo = generated."ida-pro-mcp";
  py = python3Packages;
in
py.buildPythonApplication {
  pname = "ida-pro-mcp";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  pyproject = true;

  build-system = [ py.setuptools ];

  dependencies = [
    py.idapro
    py."tomli-w"
  ];

  doCheck = false;

  pythonImportsCheck = [ "ida_pro_mcp" ];

  meta = with lib; {
    description = "MCP server and plugin installer for IDA Pro";
    homepage = "https://github.com/QiuChenly/ida-pro-mcp-enhancement";
    license = licenses.mit;
    mainProgram = "ida-pro-mcp";
    platforms = platforms.unix;
  };
}
