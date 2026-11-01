{
  lib,
  stdenvNoCC,
  generated,
  unzip,
  autoPatchelfHook,
  openssl,
  cctools,
  darwin,
  rcodesign,
}:

let
  sourceInfo = generated."bun-bin-${stdenvNoCC.hostPlatform.system}";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bun-bin";
  inherit (sourceInfo) version src;

  sourceRoot = if stdenvNoCC.hostPlatform.isDarwin then "bun-darwin-aarch64" else "bun-linux-x64";
  strictDeps = true;
  nativeBuildInputs = [
    unzip
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [
    cctools
    rcodesign
  ];
  buildInputs = [ openssl ] ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [ darwin.ICU ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bun "$out/bin/bun"
    ln -s bun "$out/bin/bunx"
    runHook postInstall
  '';

  postFixup = lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
    '${lib.getExe' cctools "${cctools.targetPrefix}install_name_tool"}' "$out/bin/bun" \
      -change /usr/lib/libicucore.A.dylib '${lib.getLib darwin.ICU}/lib/libicucore.A.dylib'
    '${lib.getExe rcodesign}' sign --code-signature-flags linker-signed "$out/bin/bun"
  '';

  meta = {
    description = "JavaScript runtime, bundler, test runner and package manager (official binary)";
    homepage = "https://bun.com";
    changelog = "https://bun.com/blog/bun-v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      lgpl21Only
    ];
    mainProgram = "bun";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    broken = stdenvNoCC.hostPlatform.isMusl;
  };
})
