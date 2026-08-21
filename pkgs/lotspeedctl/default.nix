{
  lib,
  buildGoModule,
  generated,
  makeWrapper,
  iproute2,
  iputils,
}:

let
  sourceInfo = generated.lotspeed;
in
buildGoModule {
  pname = "lotspeedctl";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  vendorHash = null;

  subPackages = [ "lotspeedctl" ];

  nativeBuildInputs = [ makeWrapper ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  postPatch = ''
    cat << 'EOF' > go.mod
module github.com/uk0/lotspeed

go 1.21
EOF
  '';

  postInstall = ''
    wrapProgram $out/bin/lotspeedctl \
      --prefix PATH : ${lib.makeBinPath [ iproute2 iputils ]}
  '';

  meta = {
    description = "Adaptive TCP congestion control and NeoQ controller CLI for LotSpeed";
    homepage = "https://github.com/uk0/lotspeed/tree/adaptive-accel";
    license = lib.licenses.gpl2Only;
    mainProgram = "lotspeedctl";
    platforms = lib.platforms.linux;
  };
}
