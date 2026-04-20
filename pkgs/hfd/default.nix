{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  curl,
  aria2,
  wget,
  jq,
  coreutils,
  gnugrep,
  gawk,
  gnused,
}:

stdenvNoCC.mkDerivation {
  pname = "hfd";
  version = "0-unstable-2025-09-28";

  src = fetchurl {
    url = "https://hf-mirror.com/hfd/hfd.sh";
    hash = "sha256-HbRm4lKJoUF7B91GMixAQ2hDX9sbl8+OVo/2x1sZbcc=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/hfd

    wrapProgram $out/bin/hfd \
      --prefix PATH : ${lib.makeBinPath [
        curl
        aria2
        wget
        jq
        coreutils
        gnugrep
        gawk
        gnused
      ]}

    runHook postInstall
  '';

  meta = {
    description = "Hugging Face model/dataset downloader with resume support";
    homepage = "https://hf-mirror.com/hfd/hfd.sh";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "hfd";
  };
}
