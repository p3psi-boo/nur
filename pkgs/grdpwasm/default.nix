{
  lib,
  stdenv,
  buildGoModule,
  go,
  generated,
}:

let
  sourceInfo = generated.grdpwasm;
  version = "0-unstable-${sourceInfo.date}";

  # Shared vendor hash (same go.sum for both proxy and wasm)
  vendorHash = "sha256-sH1uotBj0o/I1pt427mq2v102at+euHuEymruKKJh3k=";

  # Extract vendored Go modules (reused by both builds)
  goModules = (buildGoModule {
    pname = "grdpwasm-modules";
    inherit version;
    src = sourceInfo.src;
    inherit vendorHash;
    subPackages = [ ]; # don't build anything, just extract modules
  }).goModules;

  # ── Proxy binary (native Go) ────────────────────────────
  proxy = buildGoModule {
    pname = "grdpwasm-proxy";
    inherit version;
    src = sourceInfo.src;
    inherit vendorHash;

    subPackages = [ "proxy" ];

    ldflags = [
      "-s"
      "-w"
    ];

    env = {
      CGO_ENABLED = "0";
      GOFLAGS = "-trimpath";
    };

    meta = {
      description = "WebSocket-to-TCP proxy for grdpwasm (web RDP client)";
      homepage = "https://github.com/nakagami/grdpwasm";
      license = lib.licenses.gpl3Only;
      mainProgram = "proxy";
      platforms = lib.platforms.linux;
    };
  };

  # ── WASM binary (Go → js/wasm) ──────────────────────────
  wasm = stdenv.mkDerivation {
    pname = "grdpwasm-wasm";
    inherit version;
    src = sourceInfo.src;

    nativeBuildInputs = [ go ];

    buildPhase = ''
      runHook preBuild

      export GOROOT="${go}/share/go"
      export HOME=$(mktemp -d)

      ln -sf ${goModules} vendor

      GOOS=js GOARCH=wasm go build -trimpath -ldflags="-s -w" -o main.wasm .

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/grdpwasm
      cp main.wasm $out/share/grdpwasm/
      runHook postInstall
    '';

    meta = {
      description = "Go WASM binary for grdpwasm (web RDP client)";
      homepage = "https://github.com/nakagami/grdpwasm";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.all;
    };
  };

  # ── Static files (WASM + JS runtime + HTML) ─────────────
  share = stdenv.mkDerivation {
    pname = "grdpwasm-share";
    inherit version;
    src = sourceInfo.src;

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/grdpwasm

      # WASM binary
      cp ${wasm}/share/grdpwasm/main.wasm $out/share/grdpwasm/

      # wasm_exec.js from Go toolchain
      cp "${go}/share/go/lib/wasm/wasm_exec.js" $out/share/grdpwasm/

      # HTML frontend
      cp static/index.html $out/share/grdpwasm/

      runHook postInstall
    '';

    meta = {
      description = "Static files for grdpwasm (WASM binary, JS runtime, HTML frontend)";
      homepage = "https://github.com/nakagami/grdpwasm";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.all;
    };
  };
in
# ── Top-level wrapper: bin + share outputs ────────────────
stdenv.mkDerivation {
  pname = "grdpwasm";
  inherit version;
  src = sourceInfo.src;

  dontBuild = true;

  outputs = [
    "out"
    "bin"
    "share"
  ];

  installPhase = ''
    runHook preInstall

    # bin output — proxy binary
    mkdir -p $bin/bin
    ln -sf ${proxy}/bin/proxy $bin/bin/grdpwasm-proxy

    # share output — static web files
    mkdir -p $share/share/grdpwasm
    cp ${wasm}/share/grdpwasm/main.wasm $share/share/grdpwasm/
    cp "${go}/share/go/lib/wasm/wasm_exec.js" $share/share/grdpwasm/
    cp static/index.html $share/share/grdpwasm/

    # default out — convenience links to both
    mkdir -p $out/bin $out/share/grdpwasm
    ln -sf ${proxy}/bin/proxy $out/bin/grdpwasm-proxy
    cp -r $share/share/grdpwasm/* $out/share/grdpwasm/

    runHook postInstall
  '';

  passthru = {
    inherit proxy wasm share;
  };

  meta = {
    description = "Web-based RDP client built with Go WebAssembly";
    homepage = "https://github.com/nakagami/grdpwasm";
    license = lib.licenses.gpl3Only;
    mainProgram = "grdpwasm-proxy";
    platforms = lib.platforms.linux;
  };
}
