{ final }:
python-final: _python-prev:
let
  wheelMeta =
    {
      x86_64-linux = {
        hash = "sha256-MqSBFuyEZiZ5QW2VocGIgA+k8yJcPA7YJ/cgjpo4M8U=";
        platform = "manylinux_2_28_x86_64";
      };
      aarch64-linux = {
        hash = "sha256-3neK+VfHzm0nRwHl//DrGyoFmekCQ2WeRcjQlOPl3gU=";
        platform = "manylinux_2_28_aarch64";
      };
      x86_64-darwin = {
        hash = "sha256-OuH95GT8jSJl4h/y/9jLcbuo9AzycKJBIGXOdTR3KR0=";
        platform = "macosx_10_12_x86_64";
      };
      aarch64-darwin = {
        hash = "sha256-uwVw6OjXZBQPfo/1KTnCD1iVLwW6fcrq65upR37CSe4=";
        platform = "macosx_11_0_arm64";
      };
    }
    .${final.stdenvNoCC.hostPlatform.system} or (throw "Unsupported system for cocoindex wheel: ${final.stdenvNoCC.hostPlatform.system}");
in
{
  cocoindex = python-final.buildPythonPackage rec {
    pname = "cocoindex";
    version = "1.0.0a35";
    format = "wheel";

    src = final.fetchPypi {
      inherit pname version format;
      python = "cp311";
      dist = "cp311";
      abi = "abi3";
      inherit (wheelMeta) hash platform;
    };

    dependencies = [
      python-final.click
      python-final.numpy
      python-final.psutil
      python-final.python-dotenv
      python-final.rich
      python-final."typing-extensions"
      python-final.watchfiles
    ];

    pythonImportsCheck = [ "cocoindex" ];

    doCheck = false;

    meta = with final.lib; {
      description = "Data transformation for AI";
      homepage = "https://github.com/cocoindex-io/cocoindex";
      license = licenses.asl20;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
}
