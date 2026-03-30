{
  lib,
  stdenv,
  generated,
  linux,
}:

let
  sourceInfo = generated.tcp-brutal;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "tcp-brutal";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  makeFlags = [
    "KERNEL_DIR=${lib.getDev linux}/lib/modules/${linux.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    xz brutal.ko
    install -D brutal.ko.xz $out/lib/modules/${linux.modDirVersion}/kernel/brutal.ko.xz

    runHook postInstall
  '';

  meta = {
    description = "Hysteria's congestion control algorithm ported to TCP";
    homepage = "https://github.com/apernet/tcp-brutal";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "tcp-brutal";
  };
})
