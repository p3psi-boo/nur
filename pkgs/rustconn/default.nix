{
  lib,
  stdenv,
  rustPlatform,
  generated,
  pkg-config,
  cmake,
  clang,
  openssl,
  gtk4,
  libadwaita,
  vte-gtk4,
  gettext,
  dbus,
  alsa-lib,
  wrapGAppsHook4,
  glib,
}:

let
  sourceInfo = generated.rustconn;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rustconn";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
    cmake
    clang
    rustPlatform.bindgenHook
    gettext
    wrapGAppsHook4
    glib # for glib-compile-resources
  ];

  buildInputs = [
    openssl
    gtk4
    libadwaita
    vte-gtk4
    dbus
    alsa-lib
  ];

  # Only build the GUI binary (rustconn) and CLI (rustconn-cli)
  cargoBuildFlags = [
    "-p"
    "rustconn"
    "-p"
    "rustconn-cli"
  ];

  cargoInstallFlags = [
    "-p"
    "rustconn"
    "-p"
    "rustconn-cli"
  ];

  doCheck = false;

  postInstall = ''
    # Install desktop entry and icons if they exist in the source
    if [ -d "$src/rustconn/assets" ]; then
      for size in 16 32 48 64 128 256; do
        icon="$src/rustconn/assets/icons/hicolor/''${size}x''${size}/apps/io.github.totoshko88.RustConn.png"
        if [ -f "$icon" ]; then
          mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
          cp "$icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/"
        fi
      done
    fi

    if [ -f "$src/rustconn/assets/io.github.totoshko88.RustConn.desktop" ]; then
      mkdir -p "$out/share/applications"
      cp "$src/rustconn/assets/io.github.totoshko88.RustConn.desktop" "$out/share/applications/"
    elif [ -f "$src/rustconn/io.github.totoshko88.RustConn.desktop" ]; then
      mkdir -p "$out/share/applications"
      cp "$src/rustconn/io.github.totoshko88.RustConn.desktop" "$out/share/applications/"
    fi
  '';

  meta = with lib; {
    description = "Modern connection manager for Linux — SSH, RDP, VNC, SPICE, and more";
    homepage = "https://github.com/totoshko88/RustConn";
    changelog = "https://github.com/totoshko88/RustConn/releases/tag/${sourceInfo.version}";
    license = licenses.gpl3Only;
    mainProgram = "rustconn";
    platforms = platforms.linux;
  };
})
