{
  lib,
  stdenvNoCC,
  buildGoModule,
  buildNpmPackage,
  generated,
}:

let
  sourceInfo = generated.icloud-privacy-mail-v2;
  version = "0-unstable-${sourceInfo.date}";

  frontend = (buildNpmPackage.override { stdenv = stdenvNoCC; }) {
    pname = "icloud-privacy-mail-v2-frontend";
    inherit version;
    inherit (sourceInfo) src;
    sourceRoot = "${sourceInfo.src.name}/frontend";

    # The frontend only needs Node.js and prebuilt native npm modules, not a compiler.
    npmDepsHash = "sha256-0B17ZxNQYzKhPeN+MfwUNzT0p67dLvLokjveHkc3MBQ=";
    npmFlags = [ "--ignore-scripts" ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist/. "$out/"
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "icloud-privacy-mail-v2";
  inherit version;
  inherit (sourceInfo) src;

  vendorHash = "sha256-5WaCZ29wuU/aP05IBHTM0WhELYrYoerGlIS3QxoXL5o=";

  subPackages = [ "." ];
  doCheck = false;

  # modernc.org/sqlite is pure Go: no C toolchain or shared SQLite at runtime.
  env.CGO_ENABLED = "0";

  postConfigure = ''
    rm -rf internal/webui/dist
    mkdir -p internal/webui/dist
    cp -r ${frontend}/. internal/webui/dist/
  '';

  ldflags = [
    "-s"
    "-w"
    "-X=icloud-privacy-mail-v2/internal/buildinfo.Version=${version}"
    "-X=icloud-privacy-mail-v2/internal/buildinfo.Commit=${sourceInfo.version}"
  ];

  postInstall = ''
    mv "$out/bin/icloud-privacy-mail-v2" "$out/bin/ipm-server"
    install -Dm644 config.example.json "$out/share/icloud-privacy-mail-v2/config.example.json"
  '';

  passthru = {
    inherit frontend;
  };

  meta = {
    description = "iCloud Hide My Email manager with an embedded web interface and SQLite storage";
    homepage = "https://github.com/xiuxiu56/iCloud-Privacy-Mail-v2";
    # Upstream does not include a license.
    license = lib.licenses.unfree;
    mainProgram = "ipm-server";
    platforms = lib.platforms.unix;
  };
}
