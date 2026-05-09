{ generated, lib }:
python-final: _python-prev: {
  harlequin-mysql = python-final.buildPythonPackage {
    pname = "harlequin-mysql";
    version = lib.removePrefix "v" generated.harlequin-mysql.version;
    inherit (generated.harlequin-mysql) src;
    pyproject = true;

    build-system = [
      python-final.hatchling
    ];

    dependencies = [
      python-final.mysql-connector
    ]
    ++ lib.optional (python-final.pythonAtLeast "3.14") python-final.duckdb;

    # To prevent circular dependency
    # as harlequin-mysql requires harlequin which requires harlequin-mysql
    doCheck = false;
    pythonRemoveDeps = [
      "harlequin"
    ];

    meta = {
      description = "Harlequin adapter for MySQL/MariaDB";
      homepage = "https://github.com/tconbeer/harlequin-mysql";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ ];
    };
  };
}
