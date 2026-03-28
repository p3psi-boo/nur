{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.coe;
  version = lib.removePrefix "v" sourceInfo.version;
in
buildGoModule {
  pname = "coe";
  inherit version;

  src = sourceInfo.src;

  # Upstream v0.0.6 misses the module checksum line required by `go mod vendor`.
  postPatch = ''
    grep -q '^golang.org/x/sys v0.40.0 h1:' go.sum || \
      echo 'golang.org/x/sys v0.40.0 h1:DBZZqJ2Rkml6QMQsZywtnjnnGvHza6BTfYFWY9kjEWQ=' >> go.sum
  '';

  vendorHash = "sha256-LUytq4Cow3TYOTZThdIsX1R4DnRw9sy4AuOQYi+8Ht8=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${sourceInfo.version}"
    "-X main.builtBy=nix"
  ];

  meta = {
    description = "Zero-GUI Linux voice input tool";
    homepage = "https://github.com/quailyquaily/coe";
    mainProgram = "coe";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
