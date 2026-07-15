{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
  makeWrapper,
  makeFontsConf,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libpulseaudio,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  wayland,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  xdg-utils,
  freefont_ttf,
  ipafont,
  liberation_ttf,
  noto-fonts,
  noto-fonts-cjk-sans,
  noto-fonts-color-emoji,
  tlwg,
  unifont,
  wqy_zenhei,
  generated,
}:

let
  sourceInfo = generated.cloakbrowser;

  runtimeLibraries = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libpulseaudio
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    wayland
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
  ];

  desktopPackages = [
    adwaita-icon-theme
    gsettings-desktop-schemas
    xdg-utils
  ];

  fontsConf = makeFontsConf {
    fontDirectories = [
      freefont_ttf
      ipafont
      liberation_ttf
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      tlwg
      unifont
      wqy_zenhei
    ];
  };

  binaryLicense = {
    shortName = "cloakbrowser-binary";
    fullName = "CloakBrowser Binary License";
    url = "https://github.com/CloakHQ/CloakBrowser/blob/main/BINARY-LICENSE.md";
    free = false;
    redistributable = false;
  };
in
stdenvNoCC.mkDerivation {
  pname = "cloakbrowser";
  inherit (sourceInfo) version src;

  # The upstream binary license permits local use, but not redistribution.
  allowSubstitutes = false;
  preferLocalBuild = true;

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = runtimeLibraries ++ desktopPackages;
  runtimeDependencies = runtimeLibraries;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/cloakbrowser" "$out/bin"
    tar -xzf "$src" -C "$out/lib/cloakbrowser"
    chmod +x "$out/lib/cloakbrowser/chrome" "$out/lib/cloakbrowser/chromedriver"

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper "$out/lib/cloakbrowser/chrome" "$out/bin/cloakbrowser-chrome" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}" \
      --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH:$XDG_ICON_DIRS" \
      --suffix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
      --set FONTCONFIG_FILE "${fontsConf}" \
      --set CHROME_WRAPPER "cloakbrowser-chrome"

    makeWrapper "$out/lib/cloakbrowser/chromedriver" "$out/bin/cloakbrowser-chromedriver" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}"

    ln -s cloakbrowser-chrome "$out/bin/cloakbrowser"
  '';

  meta = {
    description = "Official CloakBrowser patched Chromium binary";
    homepage = "https://github.com/CloakHQ/CloakBrowser";
    license = binaryLicense;
    mainProgram = "cloakbrowser";
    platforms = [ "x86_64-linux" ];
    hydraPlatforms = [ ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
