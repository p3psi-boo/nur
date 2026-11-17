{
  lib,
  stdenvNoCC,
  generated,
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
  version = "0-unstable-${generated.hfd.date}";

  src = generated.hfd.src;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src/hfd.sh $out/bin/hfd

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
