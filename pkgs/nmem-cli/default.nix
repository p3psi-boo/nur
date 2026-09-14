{
  lib,
  stdenv,
  unzip,
  autoPatchelfHook,
  generated,
}:

let
  sourceInfo = generated.nmem-cli;
  inherit (sourceInfo) version;

  sources = {
    x86_64-linux = generated.nmem-cli.src;
    aarch64-linux = generated.nmem-cli-aarch64-linux.src;
    x86_64-darwin = generated.nmem-cli-x86_64-darwin.src;
    aarch64-darwin = generated.nmem-cli-aarch64-darwin.src;
  };

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported platform for nmem-cli: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "nmem-cli";
  inherit version src;

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [ unzip ] ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    stdenv.cc.libc
  ];

  installPhase = ''
    runHook preInstall

    unzip -q "$src" -d wheel
    install -Dm755 \
      "wheel/nmem_cli-${version}.data/scripts/nmem" \
      "$out/bin/nmem"

    runHook postInstall
  '';

  meta = {
    description = "CLI and TUI for Nowledge Mem AI memory management";
    homepage = "https://mem.nowledge.co/";
    changelog = "https://pypi.org/project/nmem-cli/${version}/";
    license = lib.licenses.mit;
    mainProgram = "nmem";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
