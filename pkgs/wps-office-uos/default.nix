{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  # wpsoffice build-time dependencies
  alsa-lib,
  libjpeg,
  libtool,
  libxkbcommon,
  nss,
  nspr,
  udev,
  gtk3,
  libgbm,
  libusb1,
  unixodbc,
  libsForQt5,
  libxv,
  libxtst,
  libxdamage,
  libtiff,
  # wpsoffice runtime dependencies (dlopen)
  cups,
  dbus,
  pango,
}:

stdenv.mkDerivation rec {
  pname = "wps-office-uos";
  version = "11.8.2.12019";

  src = fetchurl {
    url = "https://dl-r2.nxtrace.org/wps_dist/UOS_amd64.deb";
    hash = "sha256-M/E1qDEZJYnR5VTARDVXLTHh1bOcnT9Py4/01skr0vE=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    alsa-lib
    libjpeg
    libtool
    libxkbcommon
    nspr
    udev
    gtk3
    libgbm
    libusb1
    unixodbc
    libsForQt5.qtbase
    libxdamage
    libxtst
    libxv
    libtiff
  ];

  dontWrapQtApps = true;

  stripAllList = [ "opt" ];

  runtimeDependencies = map lib.getLib [
    cups
    dbus
    pango
  ];

  unpackPhase = ''
    # Unpack the .deb file
    ar x $src
    tar -xf data.tar.xz

    # Remove unneeded files
    rm -rf usr/share/{fonts,locale}
    rm -f opt/apps/cn.wps.wps-office-pro/files/bin/misc
    rm -rf opt/apps/cn.wps.wps-office-pro/files/kingsoft/wps-office/{desktops,INSTALL}
    rm -f opt/apps/cn.wps.wps-office-pro/files/kingsoft/wps-office/office6/lib{peony-wpsprint-menu-plugin,bz2,jpeg,stdc++,gcc_s,odbc*,dbus-1}.so*

    # Remove optional plugins that depend on unavailable libraries (GTK2, Qt4, etc.)
    rm -f opt/apps/cn.wps.wps-office-pro/files/kingsoft/wps-office/office6/libwps-{cajambset,nautilusmbset,print}.so
    rm -f opt/apps/cn.wps.wps-office-pro/files/kingsoft/wps-office/office6/librpc{et,wpp,wps}api.so
    rm -f opt/apps/cn.wps.wps-office-pro/files/kingsoft/wps-office/office6/KPacketInstall
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    # Copy the entire office6 tree to $out/opt/kingsoft/wps-office (same layout as regular wpsoffice-cn)
    mkdir -p $out/opt/kingsoft/wps-office
    cp -a opt/apps/cn.wps.wps-office-pro/files/kingsoft/wps-office/* $out/opt/kingsoft/wps-office/

    # Copy wrapper scripts to $out/bin
    mkdir -p $out/bin
    cp opt/apps/cn.wps.wps-office-pro/files/bin/{wps,et,wpp,wpspdf,wpsmbset,wpsprint,quickstartoffice} $out/bin/
    chmod +x $out/bin/*

    # Fix wrapper scripts: replace hardcoded install path with $out
    for i in $out/bin/wps $out/bin/et $out/bin/wpp $out/bin/wpspdf; do
      substituteInPlace $i \
        --replace-fail /opt/apps/cn.wps.wps-office-pro/files/kingsoft/wps-office $out/opt/kingsoft/wps-office
    done

    substituteInPlace $out/bin/quickstartoffice \
      --replace-fail /opt/apps/cn.wps.wps-office-pro/files/kingsoft/wps-office $out/opt/kingsoft/wps-office \
      --replace-fail /opt/apps/cn.wps.wps-office-pro/files/bin $out/bin

    # Fix wpsprint
    substituteInPlace $out/bin/wpsprint \
      --replace-fail 'misc -wpsprint_warning' "$out/opt/kingsoft/wps-office/office6/wps -misc_linux -wpsprint_warning" 2>/dev/null || true

    # fix et/wpp/wpspdf failure to launch with no mode configured
    for i in $out/bin/wps $out/bin/et $out/bin/wpp $out/bin/wpspdf; do
      substituteInPlace $i \
        --replace-fail '[ $haveConf -eq 1 ] &&' '[ ! $currentMode ] ||'
    done

    # Copy desktop entries
    mkdir -p $out/share/applications
    for desktop in \
      wps-office-wps.desktop \
      wps-office-et.desktop \
      wps-office-wpp.desktop \
      wps-office-pdf.desktop \
      wps-office-prometheus.desktop; do
      src_desktop="opt/apps/cn.wps.wps-office-pro/entries/applications/$desktop"
      if [ -f "$src_desktop" ]; then
        cp "$src_desktop" $out/share/applications/
        substituteInPlace $out/share/applications/$desktop \
          --replace-fail /opt/apps/cn.wps.wps-office-pro/files/bin/ $out/bin/ \
          --replace-fail /opt/apps/cn.wps.wps-office-pro/entries/icons/ $out/share/icons/hicolor/
      fi
    done

    # Copy icons
    mkdir -p $out/share/icons
    cp -a opt/apps/cn.wps.wps-office-pro/entries/icons/hicolor $out/share/icons/

    runHook postInstall
  '';

  preFixup = ''
    # dlopen dependency
    patchelf --add-needed libudev.so.1 $out/opt/kingsoft/wps-office/office6/addons/cef/libcef.so

    # Use libtiff.so (v4) in place of libtiff.so.5
    for f in $(find $out -type f -name '*.so*' -o -type f -executable); do
      if patchelf --print-needed "$f" 2>/dev/null | grep -q libtiff.so.5; then
        patchelf --replace-needed libtiff.so.5 libtiff.so "$f"
      fi
    done
  '';

  # Remaining missing dependencies are from optional/non-critical plugins already removed
  autoPatchelfIgnoreMissingDeps = [
    "libpng12.so.0"
    "libmysqlclient.so.18"
  ];

  meta = {
    description = "WPS Office (UOS edition) - Office suite with Writer, Spreadsheets and Presentation";
    homepage = "http://wps-community.org";
    changelog = "https://linux.wps.cn/wpslinuxlog";
    license = lib.licenses.unfree;
    mainProgram = "wps";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    hydraPlatforms = [ ];
    maintainers = [ ];
  };
}
