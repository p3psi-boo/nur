{
  lib,
  buildGoModule,
  generated,
}:

let
  sourceInfo = generated.realitlscanner;
in
buildGoModule {
  pname = "realitlscanner";
  version = sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = "sha256-hbW2cTE0Tv3eFXHB5Jr67aN9gWAKmfeKO5758P1+36Q=";

  meta = {
    description = "A TLS server scanner for Reality";
    homepage = "https://github.com/XTLS/RealiTLScanner";
    license = lib.licenses.mpl20;
    mainProgram = "RealiTLScanner";
  };
}
