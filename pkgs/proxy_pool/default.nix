{ lib
, stdenv
, python3
, generated
, makeWrapper
}:

stdenv.mkDerivation {
  pname = "proxy_pool";
  version = "0-unstable-${generated.proxy_pool.date}";
  inherit (generated.proxy_pool) src;

  nativeBuildInputs = [ makeWrapper ];

  propagatedBuildInputs = with python3.pkgs; [
    requests
    gunicorn
    lxml
    redis
    apscheduler
    click
    flask
    werkzeug
    pproxy
  ];

  postPatch = ''
    # Fix Python 3.12+ compatibility: imp module was removed
    sed -i 's/from imp import reload as reload_six/from importlib import reload as reload_six/' util/six.py

    # Fix log directory creation on read-only filesystem (nix store)
    substituteInPlace handler/logHandler.py \
      --replace-fail "LOG_PATH = os.path.join(ROOT_PATH, 'log')" \
      'LOG_PATH = os.path.join(os.environ.get("TMPDIR", "/tmp"), "proxy_pool_log")'
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    appDir="$out/share/proxy_pool"
    install -d "$appDir" "$out/bin"

    cp -r . "$appDir/"

    makeWrapper ${python3.interpreter} "$out/bin/proxyPool" \
      --add-flags "$appDir/proxyPool.py" \
      --prefix PYTHONPATH : "$appDir:$PYTHONPATH"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Python ProxyPool for web spider";
    homepage = "https://github.com/p3psi-boo/proxy_pool";
    license = licenses.mit;
    mainProgram = "proxyPool";
    platforms = platforms.unix;
    maintainers = [ ];
  };
}
