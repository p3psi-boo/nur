{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
  generated ? null,
}:

let
  sourceInfo =
    if generated != null && generated ? sofixer then
      generated.sofixer
    else
      let
        version = "v2.1.7";
      in
      {
        inherit version;
        src = fetchFromGitHub {
          owner = "F8LEFT";
          repo = "SoFixer";
          rev = version;
          hash = "sha256-emvN0iNPoADAiH4eOPCIViNHpItKyacySu/9EK2BaeQ=";
        };
      };

  targetName = if stdenv.hostPlatform.is64bit then "SoFixer64" else "SoFixer32";
in
stdenv.mkDerivation {
  pname = "sofixer";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ] ++ lib.optionals stdenv.hostPlatform.is64bit [ "-DSO_64=ON" ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "${targetName}" "$out/bin/sofixer"

    runHook postInstall
  '';

  meta = {
    description = "Repair Android shared objects dumped from memory";
    homepage = "https://github.com/F8LEFT/SoFixer";
    license = lib.licenses.bsd3;
    mainProgram = "sofixer";
    platforms = lib.platforms.unix;
  };
}
