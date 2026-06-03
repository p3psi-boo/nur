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
    npmDepsHash = "sha256-4X1AOUzsgrbxIsrI2FKVm3Qsz/WqhIUxxS+RiIw3P6M=";

    env.CI = "true";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist $out/
      cp komari-theme.json $out/
      cp preview.png $out/ 2>/dev/null || true
      cp perview.png $out/ 2>/dev/null || true
      # Ensure both filenames exist for compatibility
      if [ -f $out/preview.png ] && [ ! -f $out/perview.png ]; then
        cp $out/preview.png $out/perview.png
      fi
      if [ -f $out/perview.png ] && [ ! -f $out/preview.png ]; then
        cp $out/perview.png $out/preview.png
      fi
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
    vendorHash = "sha256-m3UOkJ299aKop7SXho+DNl41DRHUr42OHGFfLV3OPe0=";

    env = {
      CGO_ENABLED = "1";
      GOFLAGS = "-trimpath";
    };

    preBuild = ''
      mkdir -p web/public/defaultTheme/dist
      cp -r ${komariWeb}/dist/* web/public/defaultTheme/dist/
      cp -f ${komariWeb}/komari-theme.json web/public/defaultTheme/
      if [ -f ${komariWeb}/preview.png ]; then cp -f ${komariWeb}/preview.png web/public/defaultTheme/; fi
      if [ -f ${komariWeb}/perview.png ]; then cp -f ${komariWeb}/perview.png web/public/defaultTheme/; fi
      # Compatibility: ensure both filenames exist if only one is present
      if [ -f web/public/defaultTheme/preview.png ] && [ ! -f web/public/defaultTheme/perview.png ]; then
        cp -f web/public/defaultTheme/preview.png web/public/defaultTheme/perview.png
      fi
      if [ -f web/public/defaultTheme/perview.png ] && [ ! -f web/public/defaultTheme/preview.png ]; then
        cp -f web/public/defaultTheme/perview.png web/public/defaultTheme/preview.png
      fi
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
