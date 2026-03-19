{
  stdenv,
  lib,
  fetchurl,
  autoreconfHook,
  dejagnu,
  doCheck ? false,
}:

stdenv.mkDerivation rec {
  pname = "libffi";
  version = "3.2.1";

  src = fetchurl {
    url = "https://sourceware.org/pub/libffi/${pname}-${version}.tar.gz";
    sha256 = "0dya49bnhianl0r65m65xndz6ls2jn1xngyn72gd28ls3n7bnvnh";
  };

  outputs = [
    "out"
    "dev"
    "man"
    "info"
  ];

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isRiscV [ autoreconfHook ];
  checkInputs = lib.optionals doCheck [ dejagnu ];
  inherit doCheck;

  configureFlags = [
    "--with-gcc-arch=generic" # no detection of -march/-mtune
    "--enable-pax_emutramp"
  ];

  preCheck = ''
    # The tests use -O0 which is not compatible with -D_FORTIFY_SOURCE.
    NIX_HARDENING_ENABLE=''${NIX_HARDENING_ENABLE/fortify/}
  '';

  dontStrip = stdenv.hostPlatform != stdenv.buildPlatform;

  # Install headers and libs in the right places.
  postFixup = ''
    mkdir -p "$dev/"
    mv "$out/lib/${pname}-${version}/include" "$dev/include"
    rmdir "$out/lib/${pname}-${version}"
    substituteInPlace "$dev/lib/pkgconfig/libffi.pc" \
      --replace 'includedir=''${libdir}/${pname}-${version}' "includedir=$dev"
  '';

  meta = {
    description = "A foreign function call interface library (libffi 3.2.x compatibility)";
    homepage = "http://sourceware.org/libffi/";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
