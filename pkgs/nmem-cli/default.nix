{
  lib,
  stdenv,
  uv-builder,
  makeWrapper,
  rsync,
}:

let
  pythonEnv = uv-builder.buildUvPackage {
    pname = "nmem-cli";
    version = "0.6.14";
    lockFile = ./uv.lock;
    bins = [ "nmem" ];
    pyprojectOverrides = _final: prev: {
      # Disable nmem-cli-env (the virtual project) to avoid collision with nmem-cli
      "nmem-cli-env" = prev."nmem-cli-env".overrideAttrs (_old: {
        # Remove dist-info files that conflict with nmem-cli
        postInstall = ''
          rm -rf $out/lib/python*/site-packages/nmem_cli-*.dist-info
          rm -rf $out/lib/python*/site-packages/nmem_cli
        '';
      });
    };
    meta = {
      description = "CLI and TUI for Nowledge Mem - AI memory management";
    };
  };
in

stdenv.mkDerivation {
  pname = "nmem-cli";
  version = "0.6.14";

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper rsync ];

  installPhase = ''
    mkdir -p $out

    # Copy uv2nix-built Python environment
    ${rsync}/bin/rsync -a --chmod=u+w ${pythonEnv}/ $out/

    # Wrap the nmem binary to ensure it can find its dependencies
    wrapProgram $out/bin/nmem \
      --set PYTHONPATH "${pythonEnv}/lib/python3.13/site-packages:$PYTHONPATH"
  '';

  meta = {
    description = "CLI and TUI for Nowledge Mem - AI memory management";
    homepage = "https://mem.nowledge.co/";
    license = lib.licenses.mit;
    mainProgram = "nmem";
    platforms = lib.platforms.all;
  };
}
