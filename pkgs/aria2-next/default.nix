{
  lib,
  stdenv,
  generated,
  autoPatchelfHook,
  makeWrapper,
  cacert,
  testers,
  runCommand,
  python3,
}:

let
  sourceInfo = generated."aria2-next-${stdenv.hostPlatform.system}";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "aria2-next";
  inherit (sourceInfo) version src;

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/aria2-next"
    runHook postInstall
  '';

  # Upstream statically links OpenSSL, whose default CA path is not a Nix path.
  # Keep explicit SSL_CERT_FILE overrides and --ca-certificate working.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram "$out/bin/aria2-next" \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/aria2-next" --version | grep -F "${finalAttrs.version}"
    "$out/bin/aria2-next" --help > /dev/null
    runHook postInstallCheck
  '';

  passthru.tests = {
    version = testers.testVersion { package = finalAttrs.finalPackage; };
    smoke =
      runCommand "aria2-next-smoke-test"
        {
          nativeBuildInputs = [
            finalAttrs.finalPackage
            python3
          ];
        }
        ''
          python ${./smoke-test.py}
          touch "$out"
        '';
  };

  meta = {
    description = "Aria2-compatible download engine built on modern protocol libraries";
    homepage = "https://github.com/AnInsomniacy/aria2-next";
    changelog = "https://github.com/AnInsomniacy/aria2-next/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl2Plus;
    mainProgram = "aria2-next";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
