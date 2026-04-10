{ stdenv
, lib
, fetchurl
, dpkg
, makeWrapper
, autoPatchelfHook
, gst_all_1
, gtk3
, webkitgtk_4_1
, libayatana-appindicator
, zstd
, libiconv
, libcxx
, openssl
, xdotool
, zenity
, curl
, glib
, nss
, nspr
, alsa-lib
, cups
, dbus
, libdrm
, libxkbcommon
, mesa
, libX11
, libXcomposite
, libXdamage
, libXext
, libXfixes
, libXrandr
, libxcb
, systemd
}:

let
  # Download with browser UA to avoid 403
  src = fetchurl {
    name = "nowledge-mem-0.6.19.deb";
    url = "https://nowled.ge/download-mem-deb";
    sha256 = "0j0r53pr4v6danfybwdh2zcdgpaxindys6q9bkbr0hfd1wys83sf";
    curlOpts = "-A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'";
  };
in
stdenv.mkDerivation rec {
  pname = "nowledge-mem";
  version = "0.6.19";

  inherit src;

  nativeBuildInputs = [
    dpkg
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gtk3
    webkitgtk_4_1
    libayatana-appindicator
    zstd
    libiconv
    libcxx
    openssl
    xdotool
    zenity
    curl
    glib
    nss
    nspr
    alsa-lib
    cups
    dbus
    libdrm
    libxkbcommon
    mesa
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
    systemd
  ];

  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src ./extracted
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r extracted/usr/* $out/

    # Rename the directory with space to use a hyphen
    mv "$out/lib/Nowledge Mem" $out/lib/nowledge-mem

    # Wrap the binary with proper environment
    mv $out/bin/nowledge-mem $out/bin/.nowledge-mem-unwrapped
    makeWrapper $out/bin/.nowledge-mem-unwrapped $out/bin/nowledge-mem \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs} \
      --prefix PATH : ${lib.makeBinPath [ xdotool zenity curl ]} \
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1

    # Auto patch bundled libraries
    addAutoPatchelfSearchPath $out/lib/nowledge-mem

    runHook postInstall
  '';

  meta = with lib; {
    description = "Personal memory and context management system";
    longDescription = ''
      A local-first memory and context management system that visualizes
      and manages your memories, thoughts, and knowledge connections
      for AI-powered workflows.
    '';
    homepage = "https://nowled.ge";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "nowledge-mem";
  };
}
