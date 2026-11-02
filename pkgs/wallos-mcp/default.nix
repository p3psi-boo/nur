{
  lib,
  buildNpmPackage,
  nodejs_24,
  makeWrapper,
  generated,
}:
let
  sourceInfo = generated.wallos-mcp;
in
(buildNpmPackage.override { nodejs = nodejs_24; }) {
  pname = "wallos-mcp";
  version = "0-unstable-${sourceInfo.date}";
  src = sourceInfo.src;

  npmDepsHash = "sha256-v5CWEulm2Csl6JVrMccapW5Io4jh+WWnGZMnFcIAJ4U=";
  npmDepsFetcherVersion = 2;
  nativeBuildInputs = [ makeWrapper ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    npm run check
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    npm prune --omit=dev --ignore-scripts
    appDir="$out/lib/wallos-mcp"
    mkdir -p "$appDir" "$out/bin"
    cp -r dist node_modules package.json LICENSE THIRD_PARTY_NOTICES.md "$appDir/"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/wallos-mcp" \
      --set-default NODE_ENV production \
      --add-flags "--env-file-if-exists=.env $appDir/dist/index.js"
    runHook postInstall
  '';

  meta = {
    description = "Stateless MCP HTTP server for Wallos subscription management";
    homepage = "https://github.com/p3psi-boo/wallos-mcp";
    license = lib.licenses.wtfpl;
    mainProgram = "wallos-mcp";
    platforms = lib.platforms.unix;
  };
}
