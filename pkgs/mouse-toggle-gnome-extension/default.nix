{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "mouse-toggle-gnome-extension";
  version = "0.1.0";

  src = ./extension;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    extensionDir=$out/share/gnome-shell/extensions/mouse-toggle@bubu
    mkdir -p "$extensionDir"
    cp -r ./* "$extensionDir"/

    runHook postInstall
  '';

  meta = {
    description = "GNOME Shell extension: toggle mouse input via a panel icon button.";
    platforms = lib.platforms.linux;
    license = lib.licenses.mit;
  };
}

