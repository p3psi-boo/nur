{
  generated,
  lib,
  makeWrapper,
  python3,
}:

let
  sourceInfo = generated.ecloud-cloudpc-keepalive;
  py = python3.pkgs;
  runtimeDependencies = [
    py.flask
    py.pycryptodome
    py.requests
  ];
  pythonEnv = python3.withPackages (_: runtimeDependencies);
in
py.buildPythonApplication {
  pname = "ecloud-cloudpc-keepalive";
  version = "0-unstable-${sourceInfo.date}";

  inherit (sourceInfo) src;

  format = "other";

  nativeBuildInputs = [ makeWrapper ];

  dependencies = runtimeDependencies;

  postPatch = ''
    substituteInPlace main.py \
      --replace-fail 'os.path.join(os.path.dirname(os.path.abspath(__file__)), "cloud_pc.json")' 'os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "ecloud-cloudpc-keepalive", "cloud_pc.json")' \
      --replace-fail 'def save_config(cfg: dict) -> None:' $'def save_config(cfg: dict) -> None:\n    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)' \
      --replace-fail '        json.dump(cfg, f, ensure_ascii=False, indent=2)' $'        json.dump(cfg, f, ensure_ascii=False, indent=2)\n    os.chmod(CONFIG_FILE, 0o600)'

    substituteInPlace web/server.py \
      --replace-fail 'os.path.join(_PROJECT_ROOT, "cloud_pc.json")' 'os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "ecloud-cloudpc-keepalive", "cloud_pc.json")' \
      --replace-fail 'def _save_cfg(cfg: dict):' $'def _save_cfg(cfg: dict):\n    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)' \
      --replace-fail '            json.dump(cfg, f, ensure_ascii=False, indent=2)' $'            json.dump(cfg, f, ensure_ascii=False, indent=2)\n            os.chmod(tmp_file, 0o600)'
  '';

  installPhase = ''
    runHook preInstall

    appDir=$out/libexec/ecloud-cloudpc-keepalive
    mkdir -p "$appDir" $out/bin
    cp -r -- *.py web "$appDir/"

    makeWrapper ${pythonEnv}/bin/python $out/bin/ecloud-cloudpc-keepalive \
      --add-flags "$appDir/main.py"

    runHook postInstall
  '';

  checkPhase = ''
    runHook preCheck
    python -m unittest discover -s tests -v
    runHook postCheck
  '';

  meta = {
    description = "Protocol-level keepalive tool for China Mobile eCloud computers";
    homepage = "https://github.com/p3psi-boo/ecloud-cloudpc-keepalive";
    license = lib.licenses.unfree;
    mainProgram = "ecloud-cloudpc-keepalive";
    platforms = lib.platforms.linux;
  };
}
