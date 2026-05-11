{
  lib,
  stdenv,
  generated,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hev-socks5-server";
  version = generated.hev-socks5-server.version;

  src = generated.hev-socks5-server.src;

  preBuild = ''
    echo "${finalAttrs.version}" > .rev-id
  '';

  makeFlags = [
    "INSTDIR=${placeholder "out"}"
  ];

  buildFlags = [ "exec" ];
  installTargets = [ "install" ];

  meta = {
    description = "A lightweight, fast and reliable socks5 server";
    homepage = "https://github.com/heiher/hev-socks5-server";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "hev-socks5-server";
  };
})
