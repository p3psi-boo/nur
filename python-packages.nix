# Python package overrides
# Extends Python packages with custom modifications
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      picosvg = python-prev.picosvg.overridePythonAttrs (_oldAttrs: {
        doCheck = false;
      });

      idapro = python-final.buildPythonPackage rec {
        pname = "idapro";
        version = "0.0.7";
        format = "setuptools";

        src = final.fetchPypi {
          inherit pname version;
          hash = "sha256-Cy4YSxnk2EBOpIsfF/ObIbBUkxMVlA7pcW74VZFEmI8=";
        };

        doCheck = false;

        meta = with final.lib; {
          description = "IDA Library Python module";
          homepage = "https://pypi.org/project/idapro/";
          license = licenses.mit;
        };
      };
    })
  ];
}
