{ final }:
python-final: _python-prev: {
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
}
