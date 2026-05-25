{
  lib,
  symlinkJoin,
  buildDartApplication,
  generated,
}:

let
  sourceInfo = generated.mobilepi;
  version = "0-unstable-${sourceInfo.date}";

  mkComponent =
    {
      pname,
      packageRoot,
      pubspecLock,
      mainProgram,
    }:
    buildDartApplication {
      inherit pname version packageRoot;

      inherit (sourceInfo) src;
      setSourceRoot = ''
        sourceRoot=$(echo */${packageRoot})
      '';
      autoPubspecLock = pubspecLock;

      meta = {
        description = "MobilePi ${pname} Dart CLI component";
        homepage = "https://github.com/p3psi-boo/MobilePi";
        license = lib.licenses.unfree;
        platforms = lib.platforms.unix;
        inherit mainProgram;
      };
    };

  hub = mkComponent {
    pname = "mobile-pi-hub";
    packageRoot = "hub";
    pubspecLock = "${sourceInfo.src}/hub/pubspec.lock";
    mainProgram = "mobile-pi-hub";

  };

  daemon = mkComponent {
    pname = "mobile-pi-daemon";
    packageRoot = "node";
    pubspecLock = "${sourceInfo.src}/node/pubspec.lock";
    mainProgram = "mobile-pi-daemon";
  };
in
symlinkJoin {
  name = "mobilepi-${version}";
  paths = [
    hub
    daemon
  ];

  postBuild = ''
    mv $out/bin/hub $out/bin/mobile-pi-hub
    mv $out/bin/daemon $out/bin/mobile-pi-daemon
  '';

  passthru = {
    inherit hub daemon;
  };

  meta = {
    description = "Dart CLI components for MobilePi";
    homepage = "https://github.com/p3psi-boo/MobilePi";
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
    mainProgram = "mobile-pi-hub";
  };
}
