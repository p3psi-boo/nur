{
  buildGoModule,
  generated,
  go_1_26,
  lib,
}:

let
  sourceInfo = generated.dagu;
in
(buildGoModule.override { go = go_1_26; }) (finalAttrs: {
  pname = "dagu";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  subPackages = [ "cmd" ];

  env.CGO_ENABLED = "0";

  vendorHash = "sha256-VZlskGF/qsZ8UeaGuaWF9+biAHcdxo34wmQJeFua+c8=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${sourceInfo.version}"
  ];

  postInstall = ''
    if [ -e "$out/bin/cmd" ]; then
      mv "$out/bin/cmd" "$out/bin/dagu"
    fi
  '';

  doCheck = false;

  meta = {
    description = "Self-contained, lightweight workflow engine";
    homepage = "https://github.com/dagu-org/dagu";
    changelog = "https://docs.dagu.sh/reference/changelog";
    license = lib.licenses.gpl3Only;
    mainProgram = "dagu";
  };
})
