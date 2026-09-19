{
  lib,
  stdenv,
  zig_0_16,
  makeWrapper,
  curl,
  generated,
}:

let
  sourceInfo = generated.codex-auth;
  version = lib.removePrefix "v" sourceInfo.version;
in
stdenv.mkDerivation {
  pname = "codex-auth";
  inherit version;

  src = sourceInfo.src;

  nativeBuildInputs = [
    zig_0_16.hook
    makeWrapper
  ];

  zigBuildFlags = [ "-Doptimize=ReleaseSmall" ];

  # The upstream suite includes integration and live workflow tests.
  dontUseZigCheck = true;

  postInstall = ''
    wrapProgram "$out/bin/codex-auth" \
      --prefix PATH : ${lib.makeBinPath [ curl ]}
  '';

  meta = {
    description = "CLI for switching Codex accounts";
    homepage = "https://github.com/loongphy/codex-auth";
    changelog = "https://github.com/loongphy/codex-auth/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "codex-auth";
    platforms = lib.platforms.unix;
  };
}
