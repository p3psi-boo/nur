{
  lib,
  stdenv,
  fetchFromGitHub,
  linux,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tcp-brutal";
  version = "1.0.3";

  src = fetchFromGitHub {
    owner = "apernet";
    repo = "tcp-brutal";
    tag = "v${finalAttrs.version}";
    hash = "sha256-rx8JgQtelssslJhFAEKq73LsiHGPoML9Gxvw0lsLacI=";
  };

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
