{
  lib,
  stdenv,
  rustPlatform,
  generated,
  pkg-config,
  openssl,
}:

let
  sourceInfo = generated.substack-dl;
in
rustPlatform.buildRustPackage {
  pname = "substack-dl";
  version = sourceInfo.date;

  src = sourceInfo.src;

  cargoHash = "sha256-qrhGpYT7dRgs/Isfb1mWceFoN93fuhH7l0i08wm4ZCw=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  meta = with lib; {
    description = "Download all public posts from any Substack newsletter";
    homepage = "https://github.com/p3psi-boo/substack-dl";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "substack-dl";
  };
}
