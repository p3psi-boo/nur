{
  lib,
  buildGoModule,
  generated,
  go_1_26,
  makeWrapper,
}:

let
  sourceInfo = generated.open-coreui;
in
(buildGoModule.override { go = go_1_26; }) {
  pname = "open-coreui";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  modRoot = "backend";
  subPackages = [ "cmd/openwebui" ];

  vendorHash = "sha256-f2nvepWJeRySlwBgg30OJBfbi1GY9S/RSyKvQMAqFOg=";

  nativeBuildInputs = [ makeWrapper ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false;

  postInstall = ''
    mkdir -p "$out/share/open-coreui/static"
    if [ -d ../open-webui/backend/open_webui/static ]; then
      cp -r ../open-webui/backend/open_webui/static/. "$out/share/open-coreui/static/"
    fi

    mv "$out/bin/openwebui" "$out/bin/open-coreui-unwrapped"
    makeWrapper "$out/bin/open-coreui-unwrapped" "$out/bin/open-coreui" \
      --set-default STATIC_DIR "$out/share/open-coreui/static"
  '';

  meta = {
    description = "Lightweight Open WebUI backend server implementation";
    homepage = "https://github.com/xxnuo/open-coreui";
    license = lib.licenses.unfree;
    mainProgram = "open-coreui";
    platforms = lib.platforms.unix;
  };
}
