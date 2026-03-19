{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  fontconfig,
  freetype,
  libX11,
  libXext,
  libXi,
  libXrender,
  libXtst,
  zlib,
  wayland,
}:

stdenv.mkDerivation rec {
  pname = "minilpa";
  version = "1.1.1";

  src = fetchurl {
    url = "https://github.com/EsimMoe/MiniLPA/releases/download/v${version}/MiniLPA-Linux-x86_64.zip";
    hash = "sha256-y04l34ACd1k2Ps9t5xufoTVxnFkktjep2Xbao5wOTGw=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    fontconfig
    freetype
    libX11
    libXext
    libXi
    libXrender
    libXtst
    zlib
    wayland
    stdenv.cc.cc.lib  # For libstdc++ and libgcc_s
  ];

  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    mkdir -p $out

    # Copy all files
    cp -r bin lib $out/

    # Make the binary executable
    chmod +x $out/bin/MiniLPA

    # The binary already has the correct rpath, but we need to wrap it for proper library loading
    wrapProgram $out/bin/MiniLPA \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}:$out/lib:$out/lib/runtime/lib"
  '';

  meta = with lib; {
    description = "A small eUICC/LPA management UI written in Kotlin";
    homepage = "https://github.com/EsimMoe/MiniLPA";
    license = licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "MiniLPA";
  };
}
