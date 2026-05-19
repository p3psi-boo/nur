{
  lib,
  python3,
  makeWrapper,
  generated,
}:

let
  sourceInfo = generated.jarm;
in
python3.pkgs.buildPythonApplication {
  pname = "jarm";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  # jarm is a single-file script with no setup.py
  format = "other";

  nativeBuildInputs = [ makeWrapper ];

  # ipaddress is part of Python 3.3+ stdlib, no extra deps needed
  dependencies = [ ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -Dm755 jarm.py $out/libexec/jarm.py

    makeWrapper ${python3.interpreter} $out/bin/jarm \
      --add-flags "$out/libexec/jarm.py"

    runHook postInstall
  '';

  doCheck = false;

  meta = with lib; {
    description = "JARM TLS server fingerprinting tool";
    homepage = "https://github.com/salesforce/jarm";
    license = licenses.bsd3;
    mainProgram = "jarm";
    platforms = platforms.unix;
    maintainers = [ ];
  };
}
