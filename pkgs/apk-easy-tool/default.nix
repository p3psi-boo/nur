{
  lib,
  stdenvNoCC,
  fetchzip,
  wineWow64Packages,
}:

let
  pname = "apk-easy-tool";
  version = "1.60";
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchzip {
    url = "https://github.com/mkcs121/APK-Easy-Tool/releases/download/v${version}/APK.Easy.Tool.v${version}.Portable.zip";
    stripRoot = false;
    hash = "sha256-skB3qtSlin7JVefaG/IgfAFjGz9mEZrySkLOTVjTFhg=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/${pname}" "$out/bin"
    cp -r . "$out/share/${pname}/"

    cat > "$out/bin/apk-easy-tool" <<'EOF'
@BASH@
set -euo pipefail

if [ -z "''${WINEPREFIX:-}" ]; then
  if [ -n "''${XDG_DATA_HOME:-}" ]; then
    export WINEPREFIX="$XDG_DATA_HOME/apk-easy-tool/wineprefix"
  else
    export WINEPREFIX="$HOME/.local/share/apk-easy-tool/wineprefix"
  fi
fi

mkdir -p "$WINEPREFIX"

exec @WINE@ "@OUT@/share/apk-easy-tool/source/apkeasytool.exe" "$@"
EOF

    substituteInPlace "$out/bin/apk-easy-tool" \
      --replace-fail '@BASH@' '#!${stdenvNoCC.shell}' \
      --replace-fail '@WINE@' '${lib.getExe wineWow64Packages.stable}' \
      --replace-fail '@OUT@' "$out"

    chmod +x "$out/bin/apk-easy-tool"

    install -d "$out/share/applications"
    cat > "$out/share/applications/apk-easy-tool.desktop" <<EOF
[Desktop Entry]
Name=APK Easy Tool
Comment=APK reverse engineering utility (Wine)
Exec=apk-easy-tool
Terminal=false
Type=Application
Categories=Development;Utility;
StartupNotify=true
EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Easy tool for modifying APK files (Wine wrapper)";
    homepage = "https://github.com/mkcs121/APK-Easy-Tool";
    downloadPage = "https://github.com/mkcs121/APK-Easy-Tool/releases";
    mainProgram = "apk-easy-tool";
    license = licenses.unfree;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
