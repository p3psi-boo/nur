{
  lib,
  stdenvNoCC,
  nodejs_22,
  pnpm_11,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
  generated,
}:
let
  sourceInfo = generated.latch;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "latch";
  version = "0-unstable-${sourceInfo.date}";
  src = sourceInfo.src;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-alx0W5mHPuG2+Y8Qavx8EU7TTe30tLRGBpom8JAdErI=";
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm_11
    pnpmConfigHook
    makeWrapper
  ];

  postPatch = ''
    # An unbracketed IPv6 bind address is not a valid URL authority.
    substituteInPlace packages/daemon/src/http.ts \
      --replace-fail 'new URL(req.url ?? "/", `http://''${host}`)' \
        'new URL(req.url ?? "/", "http://127.0.0.1")' \
      --replace-fail 'listening http://''${host}:''${boundPort}' \
        'listening http://''${host.includes(":") ? "[" + host + "]" : host}:''${boundPort}'
  '';

  buildPhase = ''
    runHook preBuild
    pnpm build:daemon
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pnpm --filter @latch/daemon test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 bin/latch.cjs "$out/libexec/latch/latch.cjs"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/latch" \
      --add-flags "$out/libexec/latch/latch.cjs"
    runHook postInstall
  '';

  meta = {
    description = "HTTP, WebSocket and MCP daemon for the Latch browser extension";
    homepage = "https://github.com/p3psi-boo/latch";
    license = lib.licenses.wtfpl;
    mainProgram = "latch";
    platforms = lib.platforms.unix;
  };
})
