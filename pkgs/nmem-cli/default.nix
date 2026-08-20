{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}:

let
  pname = "nmem-cli";
  version = "0.10.65";

  # PyPI ships a Rust binary inside a platform wheel (no sdist / no Python deps
  # since 0.10). Classic packages/<dist>/... URLs redirect to the hashed path.
  sources = {
    x86_64-linux = {
      url = "https://files.pythonhosted.org/packages/py3/n/nmem_cli/nmem_cli-${version}-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-JlQKPJfGy9lSUnn4GQ4gxiD0DaJRYldoZc7n8mq/XRU=";
    };
    aarch64-linux = {
      url = "https://files.pythonhosted.org/packages/py3/n/nmem_cli/nmem_cli-${version}-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
      hash = "sha256-R1xgZ+XBDOYN7Z4bGtZ9jKF5JVWeMNXKI8mk8efaB3Q=";
    };
    aarch64-darwin = {
      url = "https://files.pythonhosted.org/packages/py3/n/nmem_cli/nmem_cli-${version}-py3-none-macosx_11_0_arm64.whl";
      hash = "sha256-HdKivHXTIH9lm2/Yv95Z7rdP4Xs/NJtW0kL0O8t6d70=";
    };
    x86_64-darwin = {
      url = "https://files.pythonhosted.org/packages/py3/n/nmem_cli/nmem_cli-${version}-py3-none-macosx_10_12_x86_64.whl";
      hash = "sha256-Ds8wLO+xQA+4OosU/SyyVABSysL2Q5luHMC2UOkBz84=";
    };
  };

  srcInfo =
    sources.${stdenv.hostPlatform.system}
      or (throw "nmem-cli: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    inherit (srcInfo) url hash;
  };

  nativeBuildInputs = [ unzip ] ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontBuild = true;
  dontConfigure = true;
  # Prebuilt Rust release binary.
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 nmem_cli-${version}.data/scripts/nmem "$out/bin/nmem"
    runHook postInstall
  '';

  meta = {
    description = "CLI and TUI for Nowledge Mem - AI memory management";
    homepage = "https://mem.nowledge.co/";
    downloadPage = "https://pypi.org/project/nmem-cli/";
    license = lib.licenses.mit;
    mainProgram = "nmem";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
