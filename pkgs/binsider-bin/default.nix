{
  lib,
  stdenvNoCC,
  generated,
}:

let
  sources = {
    x86_64-linux = generated.binsider-bin;
    aarch64-linux = generated.binsider-bin-aarch64-linux;
    x86_64-darwin = generated.binsider-bin-darwin-x64;
    aarch64-darwin = generated.binsider-bin-darwin-arm64;
  };

  sourceInfo =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "binsider-bin: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "binsider-bin";
  inherit (sourceInfo) version src;

  sourceRoot = "binsider-${sourceInfo.version}";

  installPhase = ''
    runHook preInstall

    install -Dm755 binsider $out/bin/binsider
    install -Dm644 README.md $out/share/doc/binsider-bin/README.md
    install -Dm644 CHANGELOG.md $out/share/doc/binsider-bin/CHANGELOG.md
    install -Dm644 LICENSE-APACHE $out/share/licenses/binsider-bin/LICENSE-APACHE
    install -Dm644 LICENSE-MIT $out/share/licenses/binsider-bin/LICENSE-MIT

    runHook postInstall
  '';

  meta = with lib; {
    description = "Analyze ELF binaries like a boss";
    homepage = "https://binsider.dev";
    downloadPage = "https://github.com/orhun/binsider/releases";
    changelog = "https://github.com/orhun/binsider/releases/tag/v${sourceInfo.version}";
    license = with licenses; [ mit asl20 ];
    mainProgram = "binsider";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
