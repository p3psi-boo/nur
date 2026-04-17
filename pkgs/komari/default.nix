{
  lib,
  stdenv,
  buildGoModule,
  buildNpmPackage,
  generated,
}:

let
  backendVersion = "0-unstable-${generated.komari.date}";
  backendCommit = generated.komari.version;

  komariWeb = buildNpmPackage {
    pname = "komari-web";
    version = "0-unstable-${generated.komari-web.date}";
    inherit (generated.komari-web) src;
    npmDepsHash = "sha256-klP49fxwnuYBNaE7huKdpTDreieCGDnO3E4eOE3j+CE=";

    env.CI = "true";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist $out/
      cp *.json $out/ 2>/dev/null || true
      cp preview.png perview.png $out/ 2>/dev/null || true
      runHook postInstall
    '';

    meta = {
      description = "Komari monitoring dashboard web frontend";
      homepage = "https://github.com/komari-monitor/komari-web";
      license = lib.licenses.unfree;
      platforms = lib.platforms.all;
    };
  };

  komariBackend = buildGoModule {
    pname = "komari";
    version = backendVersion;
    inherit (generated.komari) src;
    vendorHash = "sha256-zF2nblVafBt5dbXaZdRwa1RNXPOxJKPAEH7SqaX4c1c=";

    env = {
      CGO_ENABLED = "1";
      GOFLAGS = "-trimpath";
    };

    preBuild = ''
      mkdir -p public/defaultTheme
      cp -r ${komariWeb}/dist public/defaultTheme/
      for f in ${komariWeb}/*.{json,png}; do
        [ -e "$f" ] && cp "$f" public/defaultTheme/
      done
    '';

    ldflags = [
      "-s"
      "-w"
      "-X=github.com/komari-monitor/komari/utils.CurrentVersion=${backendVersion}"
      "-X=github.com/komari-monitor/komari/utils.VersionHash=${backendCommit}"
    ];
    doCheck = false;

    meta = {
      description = "Lightweight self-hosted server monitoring tool";
      homepage = "https://github.com/komari-monitor/komari";
      license = lib.licenses.unfree;
      mainProgram = "komari";
      platforms = lib.platforms.linux;
    };
  };
in

stdenv.mkDerivation {
  pname = "komari";
  version = backendVersion;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    ln -s ${komariBackend}/bin/komari $out/bin/
    runHook postInstall
  '';

  passthru = {
    inherit komariBackend komariWeb;
  };

  meta = komariBackend.meta // {
    description = "Lightweight self-hosted server monitoring tool with web dashboard";
  };
}
