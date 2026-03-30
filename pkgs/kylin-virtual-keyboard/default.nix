{
  lib,
  stdenv,
  cmake,
  pkg-config,
  glib,
  wrapGAppsHook3,
  libsForQt5,
  fcitx5,
  gsettings-qt,
  spdlog,
  generated,
}:

let
  sourceInfo = generated.kylin-virtual-keyboard;
in
stdenv.mkDerivation {
  pname = "kylin-virtual-keyboard";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  nativeBuildInputs = [
    cmake
    pkg-config
    glib
    wrapGAppsHook3
    libsForQt5.wrapQtAppsHook
  ];

  buildInputs = [
    spdlog
    fcitx5
    libsForQt5.fcitx5-qt
    gsettings-qt

    libsForQt5.qtbase
    libsForQt5.qtdeclarative
    libsForQt5.qtquickcontrols2
    libsForQt5.kwindowsystem
  ];

  # Upstream toggles window opacity frequently; on Wayland this spams warnings
  # and can cause visible flicker. Default to X11/XWayland unless the user
  # explicitly overrides QT_QPA_PLATFORM.
  qtWrapperArgs = [
    "--set-default"
    "QT_QPA_PLATFORM"
    "xcb"
  ];

  postPatch = ''
    # Upstream installs autostart entry directly into /etc, which fails in Nix builds.
    substituteInPlace data/CMakeLists.txt \
      --replace-fail "DESTINATION /etc/xdg/autostart/" 'DESTINATION ${"$"}{CMAKE_INSTALL_PREFIX}/etc/xdg/autostart/'
  '';

  postInstall = ''
    # Keep schemas in the output usable without manual compilation.
    if [ -d "$out/share/glib-2.0/schemas" ]; then
      glib-compile-schemas "$out/share/glib-2.0/schemas"
    fi
  '';

  meta = {
    description = "Virtual keyboard for Linux (openKylin / Fcitx5)";
    homepage = "https://gitee.com/openkylin/kylin-virtual-keyboard";
    license = lib.licenses.lgpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "kylin-virtual-keyboard";
  };
}
