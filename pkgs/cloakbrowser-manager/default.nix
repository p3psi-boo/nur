{
  lib,
  buildNpmPackage,
  fetchPypi,
  makeWrapper,
  procps,
  stdenvNoCC,
  xclip,
  generated,
  python313Packages,
}:

let
  sourceInfo = generated.cloakbrowser-manager;
  version = "0-unstable-${sourceInfo.date}";

  cloakbrowserPython =
    let
      pname = "cloakbrowser";
      version = "0.5.10";
    in
    python313Packages.buildPythonPackage {
      inherit pname version;

      src = fetchPypi {
        inherit pname version;
        hash = "sha256-FD/8wit0gIcJIPoJQUNuIvrNq7b48kA1xpJ+Z1OK1to=";
      };

      pyproject = true;
      build-system = [ python313Packages.hatchling ];
      dependencies = with python313Packages; [
        cryptography
        geoip2
        httpx
        playwright
        socksio
      ];

      doCheck = false;
    };

  python = python313Packages.python.withPackages (
    ps: with ps; [
      cloakbrowserPython
      fastapi
      httpx
      pydantic
      uvicorn
      websockets
    ]
  );

  frontend = buildNpmPackage {
    pname = "cloakbrowser-manager-frontend";
    inherit version;

    src = sourceInfo.src;
    sourceRoot = "${sourceInfo.src.name}/frontend";
    npmDepsHash = "sha256-3A76R2Bgtf5c7Fw5TjjFfYKLIVLvnBgZ/ZewJWn4Hok=";

    env.CI = "true";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist "$out/dist"
      runHook postInstall
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "cloakbrowser-manager";
  inherit version;
  src = sourceInfo.src;

  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace backend/vnc_manager.py \
      --replace-fail 'import logging' $'import logging\nimport os' \
      --replace-fail 'httpd_dir = "/usr/share/kasmvnc/www"' \
        'httpd_dir = os.environ.get("KASMVNC_WEB_ROOT", "/usr/share/kasmvnc/www")' \
      --replace-fail '["pkill", "-f", r"Xvnc :[0-9]"],' \
        '["pkill", "-f", r"Xvnc :[1-9][0-9][0-9]($| )"],'
  '';

  installPhase = ''
    runHook preInstall

    install -d "$out/lib/cloakbrowser-manager/frontend"
    cp -r backend "$out/lib/cloakbrowser-manager/backend"
    cp -r ${frontend}/dist "$out/lib/cloakbrowser-manager/frontend/dist"

    makeWrapper ${python}/bin/uvicorn "$out/bin/cloakbrowser-manager" \
      --add-flags 'backend.main:app --host 127.0.0.1 --port 8080 --log-level warning' \
      --prefix PATH : ${
        lib.makeBinPath [
          procps
          xclip
        ]
      } \
      --prefix PYTHONPATH : "$out/lib/cloakbrowser-manager"

    runHook postInstall
  '';

  passthru = {
    inherit cloakbrowserPython frontend;
  };

  meta = {
    description = "Self-hosted browser-profile manager for CloakBrowser";
    homepage = "https://github.com/CloakHQ/CloakBrowser-Manager";
    license = lib.licenses.mit;
    mainProgram = "cloakbrowser-manager";
    platforms = lib.platforms.linux;
  };
}
