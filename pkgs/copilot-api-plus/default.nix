{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  generated,
  jq,
}:

let
  sourceInfo = generated.copilot-api-plus;
in

buildNpmPackage {
  pname = "copilot-api-plus";
  version = "0-unstable-${sourceInfo.date}";

  src = fetchurl {
    url = "https://registry.npmjs.org/copilot-api-plus/-/copilot-api-plus-1.2.25.tgz";
    hash = "sha256-23CrY5lP9x1zO2h1OuGJzfkB1MDHXjSgARkLPauzORo=";
  };
  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json

    # Keep package metadata aligned with the vendored production-only lockfile.
    mv package.json package.json.upstream
    jq '{
      name,
      version,
      type,
      bin,
      dependencies
    }' package.json.upstream > package.json
  '';

  npmDepsHash = "sha256-irGgVvkvaI+KZLK+xd/j2CiQfwyFPqPTUbwf3IAEqYg=";
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  nativeBuildInputs = [
    makeWrapper
    jq
  ];

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/copilot-api-plus"

    install -d "$appDir" "$out/bin"
    cp -r dist package.json node_modules "$appDir/"

    makeWrapper ${nodejs}/bin/node "$out/bin/copilot-api-plus" \
      --add-flags "$appDir/dist/main.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Turn GitHub Copilot into OpenAI/Anthropic API compatible server";
    homepage = "https://github.com/imbuxiangnan-cyber/copilot-api-plus";
    license = licenses.mit;
    mainProgram = "copilot-api-plus";
    platforms = platforms.unix;
  };
}
