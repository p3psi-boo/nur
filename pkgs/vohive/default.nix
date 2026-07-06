{
  lib,
  buildGoModule,
  buildNpmPackage,
  generated,
  go_1_26,
}:

let
  sourceInfo = generated.vohive;
  version = "0-unstable-${sourceInfo.date}";

  frontend = buildNpmPackage {
    pname = "vohive-web";
    inherit version;

    src = sourceInfo.src;
    sourceRoot = "${sourceInfo.src.name}/web";

    npmDepsHash = "sha256-bnU4VQGVXPAyTEQjETgtj9SHzR4d+oF5O971RVfkDbY=";

    env.CI = "true";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist "$out/"
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "vohive";
  inherit version;

  src = sourceInfo.src;

  vendorHash = "sha256-ZRlQJ8iJ5f41zfDUorbxx2kceWJV4iC8ryEiRKyA+bA=";

  go = go_1_26;
  subPackages = [ "cmd/vohive" ];
  tags = [
    "with_utls"
    "nomsgpack"
  ];

  env = {
    CGO_ENABLED = "0";
    GOWORK = "off";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
    "-X github.com/iniwex5/vohive/internal/global.Version=${sourceInfo.version}"
    "-X github.com/iniwex5/vohive/internal/global.BuildTime=${sourceInfo.date}"
  ];

  preBuild = ''
    rm -rf internal/web/dist
    mkdir -p internal/web
    cp -r ${frontend}/dist internal/web/dist
  '';

  doCheck = false;

  postInstall = ''
    install -Dm644 packaging/openwrt/vohive/files/config.yaml \
      "$out/share/doc/vohive/config.example.yaml"
  '';

  meta = {
    description = "Management and proxy service platform for Qualcomm LTE/5G modules";
    homepage = "https://github.com/p3psi-boo/vohive";
    license = {
      spdxId = "PolyForm-Noncommercial-1.0.0";
      fullName = "PolyForm Noncommercial License 1.0.0";
      url = "https://polyformproject.org/licenses/noncommercial/1.0.0/";
      free = false;
      redistributable = true;
    };
    mainProgram = "vohive";
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
