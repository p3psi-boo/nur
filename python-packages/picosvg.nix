{ final }:
python-final: python-prev: {
  picosvg = python-prev.picosvg.overridePythonAttrs (_oldAttrs: {
    doCheck = false;
  });
}
