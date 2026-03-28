{
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
  zlib,
  ncurses,
  libxml2,
  libffi,
  elfutils,
  rocm-runtime ? null,
  version,
  sha256,
}:

stdenv.mkDerivation {
  pname = "aocc";
  inherit version;

  src =
    let
      tarName =
        if lib.versionOlder version "2.0" then
          "AOCC-${version}-Compiler.tar.xz"
        else
          "aocc-compiler-${version}.tar";
      # AMD hosts the EULA-gated downloads under a versioned subdir like aocc-5-1.
      ver2 = builtins.concatStringsSep "-" (lib.take 2 (lib.splitVersion version));
    in
    fetchurl {
      url = "https://download.amd.com/developer/eula/aocc/aocc-${ver2}/${tarName}";
      name = tarName;
      inherit sha256;
    };

  dontStrip = true;
  # Avoid nixpkgs' legacy patchELF hook; we use autoPatchelfHook.
  dontPatchELF = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    stdenv.cc.cc
    stdenv.cc.libc
    zlib
    ncurses
    libxml2
    libffi
    elfutils
  ]
  ++ lib.optionals (rocm-runtime != null && lib.versionAtLeast version "3.1.0") [ rocm-runtime ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -rv . "$out"

    rm -rf "$out/lib32"
    find "$out" -name "*-i386.so" -delete

    # Hack around lack of libtinfo in NixOS
    ln -sf ${ncurses.out}/lib/libncursesw.so.6 "$out/lib/libtinfo.so.5"
    ln -sf ${zlib}/lib/libz.so.1 "$out/lib/libz.so.1"
    ln -sf ${stdenv.cc.libc}/lib/libdl.so* "$out/lib/"

    runHook postInstall
  '';

  preFixup = ''
    # Ensure autoPatchelf can also use AOCC-shipped libraries.
    addAutoPatchelfSearchPath "$out/lib"
  '';

  passthru = {
    isClang = true;
    langFortran = true;
  };

  meta = {
    description = "AMD Optimizing C/C++ Compiler (AOCC)";
    homepage = "https://developer.amd.com/amd-aocc/";
    license = lib.licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    mainProgram = "aocc";
  };
}
