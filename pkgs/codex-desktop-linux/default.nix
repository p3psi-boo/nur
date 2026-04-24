{
  lib,
  stdenv,
  stdenvNoCC,
  generated,
  fetchurl,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  bash,
  nodejs,
  python3,
  p7zip,
  curl,
  unzip,
  gnumake,
  gcc,
  patchelf,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  glib,
  gtk3,
  pango,
  cairo,
  gdk-pixbuf,
  atk,
  at-spi2-atk,
  at-spi2-core,
  nss,
  nspr,
  dbus,
  cups,
  expat,
  libdrm,
  mesa,
  libgbm,
  alsa-lib,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
  libxkbcommon,
  libxcursor,
  libxi,
  libxtst,
  libxscrnsaver,
  libglvnd,
  systemd,
  wayland,
}:

let
  sourceInfo = generated.codex-desktop-linux;

  codexDmg = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg";
    hash = "sha256-ZdMRQRfx8DFX4paDWOfBu6ykjz/kqbybcfxvcZ6XAus=";
  };

  electronLibPath = lib.makeLibraryPath [
    glib
    gtk3
    pango
    cairo
    gdk-pixbuf
    atk
    at-spi2-atk
    at-spi2-core
    nss
    nspr
    dbus
    cups
    expat
    libdrm
    mesa
    libgbm
    alsa-lib
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
    libxkbcommon
    libxcursor
    libxi
    libxtst
    libxscrnsaver
    libglvnd
    systemd
    wayland
  ];
in
stdenvNoCC.mkDerivation {
  pname = "codex-desktop-linux";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];
  dontBuild = true;

  desktopItems = [
    (makeDesktopItem {
      name = "codex-desktop-linux";
      exec = "codex-desktop-linux-launcher";
      icon = "codex-desktop-linux";
      desktopName = "Codex Desktop Linux";
      comment = "Launch Codex Desktop on Linux (installs on first run)";
      categories = [
        "Development"
        "Utility"
      ];
      keywords = [
        "codex"
        "openai"
        "assistant"
      ];
      terminal = true;
      startupNotify = true;
    })
  ];

  installPhase = ''
    runHook preInstall

    sourceDir="$out/share/codex-desktop-linux/source"
    install -d "$sourceDir" "$out/bin"
    cp -r . "$sourceDir/"
    chmod -R u+w "$sourceDir"

    cat > "$out/bin/codex-desktop-linux" <<EOF
#!${stdenv.shell}
set -euo pipefail

root_dir="\$(pwd)"
workdir="\$(mktemp -d)"
source_dir="\$workdir/source"
cleanup() {
  rm -rf "\$workdir"
}
trap cleanup EXIT

mkdir -p "\$source_dir"
cp -R "$sourceDir"/. "\$source_dir"
chmod -R u+w "\$source_dir"
cp ${codexDmg} "\$source_dir/Codex.dmg"
chmod +x "\$source_dir/install.sh"

cd "\$source_dir"
export CODEX_INSTALL_DIR="\''${CODEX_INSTALL_DIR:-\$root_dir/codex-app}"
${bash}/bin/bash "\$source_dir/install.sh" "\$source_dir/Codex.dmg" "\$@"

install_dir="\''${CODEX_INSTALL_DIR:-\$root_dir/codex-app}"
dynamic_linker="\$(cat ${stdenv.cc}/nix-support/dynamic-linker)"

# Upstream writes /bin/bash shebangs that are not valid on NixOS hosts.
if [ -f "\$install_dir/start.sh" ]; then
  sed -i '1 s|^#!/bin/bash$|#!${bash}/bin/bash|' "\$install_dir/start.sh"
  chmod +x "\$install_dir/start.sh"
fi

# Upstream launcher expects distro-provided Electron libraries; NixOS needs explicit loader/rpath wiring.
if [ -f "\$install_dir/electron" ]; then
  ${patchelf}/bin/patchelf --set-interpreter "\$dynamic_linker" \
    --set-rpath "\$install_dir:${electronLibPath}" \
    "\$install_dir/electron"

  if [ -f "\$install_dir/chrome_crashpad_handler" ]; then
    ${patchelf}/bin/patchelf --set-interpreter "\$dynamic_linker" "\$install_dir/chrome_crashpad_handler" || true
  fi

  if [ -f "\$install_dir/chrome-sandbox" ]; then
    ${patchelf}/bin/patchelf --set-interpreter "\$dynamic_linker" "\$install_dir/chrome-sandbox" || true
  fi

  find "\$install_dir" -maxdepth 1 -name "*.so*" -type f | while read -r so; do
    ${patchelf}/bin/patchelf --set-rpath "${electronLibPath}" "\$so" 2>/dev/null || true
  done
fi
EOF

    chmod +x "$out/bin/codex-desktop-linux"

    wrapProgram "$out/bin/codex-desktop-linux" \
      --prefix PATH : ${lib.makeBinPath [
        bash
        coreutils
        findutils
        gnugrep
        gnused
        nodejs
        python3
        p7zip
        curl
        unzip
        gnumake
        gcc
        patchelf
      ]}

    cat > "$out/bin/codex-desktop-linux-launcher" <<'EOF'
#!${bash}/bin/bash
set -euo pipefail

default_install_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/codex-desktop-linux/codex-app"
export CODEX_INSTALL_DIR="''${CODEX_INSTALL_DIR:-$default_install_dir}"

if [ -x "$CODEX_INSTALL_DIR/start.sh" ]; then
  exec "$CODEX_INSTALL_DIR/start.sh" "$@"
fi

exec codex-desktop-linux "$@"
EOF
    chmod +x "$out/bin/codex-desktop-linux-launcher"

    install -d "$out/share/icons/hicolor/256x256/apps"
    install -m644 "$sourceDir/assets/codex.png" "$out/share/icons/hicolor/256x256/apps/codex-desktop-linux.png"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Nix-friendly installer wrapper for OpenAI Codex Desktop on Linux";
    homepage = "https://github.com/ilysenko/codex-desktop-linux";
    license = licenses.mit;
    mainProgram = "codex-desktop-linux";
    platforms = platforms.linux;
  };
}
