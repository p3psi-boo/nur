{
  lib,
  stdenvNoCC,
  fetchurl,
  generated,
}:

let
  sourceInfo = generated.sdbd;

  # Upstream's master currently corresponds to the v0.5 release.  The release
  # archives contain fully static binaries, avoiding the unavailable bfenv
  # source dependency.
  releaseTag = "v0.5";
  binaries = {
    x86_64 = {
      arch = "amd64";
      hash = "sha256-IC1dQCvlgLrd0f2wY2s4+ZylyC3bNXfYPvvlTM6b0jQ=";
    };
    aarch64 = {
      arch = "aarch64";
      hash = "sha256-6f9lzXMu5vIWx4xJTQTbCvNWh35UTf4iyofb0ElAz/s=";
    };
    armv7l = {
      arch = "armv7";
      hash = "sha256-0ixYJ6NeoHiqtF7mxv9lbRdAWaiu9KXh3uFf7JBQsbQ=";
    };
    i686 = {
      arch = "i386";
      hash = "sha256-Ocrys9Rr8Yu40exZ+fJOupDSIp/s7L3VfPkd8FQ43mc=";
    };
    riscv64 = {
      arch = "riscv64";
      hash = "sha256-2ivBv73/R1fd6CYf55/ypJeT5p7GaNW8IExW9GiI30A=";
    };
  };
  binary = binaries.${stdenvNoCC.hostPlatform.parsed.cpu.name};
  binarySrc = fetchurl {
    url = "https://github.com/openbfdev/sdbd/releases/download/${releaseTag}/sdbd-linux-${binary.arch}.tar.gz";
    inherit (binary) hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "sdbd";
  version = "0-unstable-${sourceInfo.date}";

  src = binarySrc;
  sourceRoot = ".";

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/sdbd $out/bin/sdbd

    runHook postInstall
  '';

  passthru = {
    updateScript = null;
    upstreamSource = sourceInfo.src;
  };

  meta = {
    description = "Lightweight, high-performance Android Debug Bridge daemon";
    homepage = "https://github.com/openbfdev/sdbd";
    license = lib.licenses.lgpl3Plus;
    mainProgram = "sdbd";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "armv7l-linux"
      "i686-linux"
      "riscv64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
