# harlequin-mysql - MySQL adapter for Harlequin SQL IDE
# https://github.com/tconbeer/harlequin-mysql
# A Harlequin adapter for MySQL/MariaDB databases
{
  lib,
  stdenv,
  uv-builder,
  makeWrapper,
  generated,
  # Runtime dependencies for mysql-connector-python
  keyutils,
  udev,
  libxcrypt,
  # For manual virtual env construction
  pkgs,
}:

let
  inherit (generated.harlequin-mysql) src version;

  # Use uv-builder with custom overrides for mysql-connector-python
  pythonEnv = uv-builder.buildUvPackage {
    pname = "harlequin-mysql-python";
    inherit version;
    lockFile = "${src}/uv.lock";
    bins = [ ];
    # Fix mysql-connector-python's bundled native libs
    # These are vendor libs that need system dependencies
    pyprojectOverrides = final: prev: {
      mysql-connector-python = prev.mysql-connector-python.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [
          keyutils
          udev
          libxcrypt
        ];
        # These bundled libs reference system libs that may not be available at build time
        # They are optional (Kerberos, WebAuthn, SASL plugins)
        autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
          "libkeyutils.so.1"
          "libudev.so.1"
          "libcrypt.so.1"
        ];
      });
    };
    meta = {
      description = "harlequin-mysql Python environment";
    };
  };
in

stdenv.mkDerivation {
  pname = "harlequin-mysql";
  inherit version src;

  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/lib/python3.13/site-packages

    # Copy the package source
    cp -r ${src}/src/harlequin_mysql $out/lib/python3.13/site-packages/

    # Copy all dependencies from the Python environment
    cp -r ${pythonEnv}/lib/python3.13/site-packages/* $out/lib/python3.13/site-packages/
  '';

  passthru = {
    inherit pythonEnv;
  };

  meta = {
    description = "MySQL adapter for Harlequin, the SQL IDE for your Terminal";
    homepage = "https://github.com/tconbeer/harlequin-mysql";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.unix;
  };
}
