{
  buildNpmPackage,
  bun,
  jq,
  lib,
  generated,
  makeWrapper,
}:

let
  sourceInfo = generated.mcp-cli;
in
buildNpmPackage {
  pname = "mcp-cli";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  postPatch = ''
    ${lib.getExe jq} 'del(.devDependencies)' package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-fgiE5hY3rSbpD6HU/9n6S6gU6r0QkTVQZ20ynWTKAfM=";
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  nativeBuildInputs = [
    jq
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/mcp-cli"
    cp -r src package.json node_modules "$out/lib/mcp-cli/"

    makeWrapper ${lib.getExe bun} "$out/bin/mcp-cli" \
      --add-flags "$out/lib/mcp-cli/src/index.ts"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Lightweight CLI for interacting with MCP servers";
    homepage = "https://github.com/philschmid/mcp-cli";
    downloadPage = "https://github.com/philschmid/mcp-cli/releases";
    license = licenses.mit;
    mainProgram = "mcp-cli";
    platforms = platforms.unix;
    sourceProvenance = [ sourceTypes.fromSource ];
  };
}
