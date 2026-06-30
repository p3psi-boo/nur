{
  lib,
  stdenv,
  fetchurl,
  buildNpmPackage,
  makeWrapper,
  nodejs_22,
  autoPatchelfHook,
}:

let
  supportedPlatforms = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];
  ripgrepPlatform =
    {
      aarch64-darwin = "arm64-darwin";
      aarch64-linux = "arm64-linux";
      x86_64-darwin = "x64-darwin";
      x86_64-linux = "x64-linux";
    }
    .${stdenv.hostPlatform.system}
      or (throw "codebuddy-code: unsupported system ${stdenv.hostPlatform.system}");
  genieTrashBinary =
    {
      aarch64-darwin = "darwin-arm64";
      aarch64-linux = "linux-arm64";
      x86_64-darwin = "darwin-x64";
      x86_64-linux = "linux-x64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "codebuddy-code: unsupported system ${stdenv.hostPlatform.system}");
in
(buildNpmPackage.override { nodejs = nodejs_22; }) rec {
  pname = "codebuddy-code";
  version = "2.114.1";

  src = fetchurl {
    url = "https://registry.npmmirror.com/@tencent-ai/codebuddy-code/-/codebuddy-code-${version}.tgz";
    hash = "sha512-KbTc2l3hXsKtSWuu2AG3fKvAb9OP6PF3/AqyNCC7Da2fjZTZrVsIUyRJz32BBGjajG5LuLAe2juge1nwtFi/Iw==";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-HwCYwKsTvevueNLyNj7FPZBei1qFHexVeVTXTy/7Y4Y=";
  npmInstallFlags = [ "--include=optional" ];
  dontNpmBuild = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    stdenv.cc.libc
  ];

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/node_modules/@tencent-ai/codebuddy-code"
    install -d "$appDir" "$out/bin"
    cp -r . "$appDir/"

    find "$appDir/vendor/ripgrep" -mindepth 1 -maxdepth 1 -type d \
      ! -name ${lib.escapeShellArg ripgrepPlatform} \
      -exec rm -rf {} +
    find "$appDir/vendor/genie-trash" -mindepth 1 -maxdepth 1 -type f \
      ! -name ${lib.escapeShellArg genieTrashBinary} \
      -delete

    makeWrapper ${nodejs_22}/bin/node "$out/bin/codebuddy" \
      --add-flags "$appDir/bin/codebuddy"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/cbc" \
      --add-flags "$appDir/bin/codebuddy"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/cbc-prewarm" \
      --add-flags "$appDir/bin/cbc-prewarm"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Tencent CodeBuddy Code AI coding assistant CLI";
    homepage = "https://cnb.cool/codebuddy/codebuddy-code";
    downloadPage = "https://www.npmjs.com/package/@tencent-ai/codebuddy-code";
    license = licenses.mit;
    mainProgram = "codebuddy";
    platforms = supportedPlatforms;
  };
}
