{ appimageTools
, fetchurl
, lib
}:

let
  pname = "nowledge-mem";
  version = "0.6.19";

  # Download AppImage with browser UA to avoid 403
  src = fetchurl {
    name = "${pname}-${version}.AppImage";
    url = "https://nowled.ge/download-mem-appimage";
    sha256 = "sha256-xpyCbO5f8SUQZCXXvlbDuhbtNo8e2bQtA39tzNkIPAw=";
    curlOptsList = [ "-A" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" ];
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # Add Wayland support libraries
  extraPkgs = pkgs: with pkgs; [
    wayland
    libdrm
    mesa
    libxkbcommon
  ];

  extraInstallCommands = ''
    # Install .desktop file (handle space in filename)
    install -m 444 -D "${appimageContents}/Nowledge Mem.desktop" $out/share/applications/nowledge-mem.desktop

    # Install icons from AppImage
    if [ -d "${appimageContents}/usr/share/icons" ]; then
      cp -r "${appimageContents}/usr/share/icons" $out/share/
    fi
  '';

  meta = with lib; {
    description = "Personal memory and context management system";
    longDescription = ''
      A local-first memory and context management system that visualizes
      and manages your memories, thoughts, and knowledge connections
      for AI-powered workflows.

      Note for Wayland users: If you encounter EGL errors, try running with:
        WEBKIT_DISABLE_DMABUF_RENDERER=1 nowledge-mem
      Or force XWayland:
        GDK_BACKEND=x11 nowledge-mem
    '';
    homepage = "https://nowled.ge";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "nowledge-mem";
  };
}
