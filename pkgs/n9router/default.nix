{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs,
  makeWrapper,
  python3,
  generated,
}:

let
  sourceInfo = generated.n9router;
  version = "0-unstable-${sourceInfo.date}";
in
buildNpmPackage {
  pname = "n9router";
  inherit version;
  src = sourceInfo.src;

  npmDepsHash = "sha256-9TKIa39Fn57GwYSA1tkmupnVr61vRD+5lYnwTepfbpw=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json

    # Replace next/font/google with a local stub to avoid network access during build
    python3 ${./patch-layout.py}
  '';

  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  # Allow prebuilt binaries for packages like sharp
  env = {
    npm_config_build_from_source = false;
  };

  # Skip the automatic npm build; we run it manually to control the process
  dontNpmBuild = true;

  buildPhase = ''
    runHook preBuild

    # Build the Next.js application
    npm run build

    # Run postbuild to copy static assets into standalone output
    npm run postbuild

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appDir="$out/lib/n9router"
    install -d "$appDir" "$out/bin"

    # Copy the standalone Next.js output
    cp -r .next/standalone/. "$appDir/"

    # Ensure static assets are present
    if [ -d .next/static ]; then
      cp -r .next/static "$appDir/.next/"
    fi

    # Copy public assets
    if [ -d public ]; then
      cp -r public "$appDir/"
    fi

    # Copy package.json for metadata
    cp package.json "$appDir/"

    # Create wrapper script that sets required environment variables
    makeWrapper ${nodejs}/bin/node "$out/bin/n9router" \
      --set NODE_ENV production \
      --set PORT 20128 \
      --set HOSTNAME 0.0.0.0 \
      --add-flags "$appDir/server.js" \
      --chdir "$appDir"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Self-hosted AI routing gateway — local proxy for Claude, Gemini, OpenAI and 40+ providers";
    homepage = "https://github.com/nightwalker89/n9router";
    license = licenses.mit;
    mainProgram = "n9router";
    platforms = platforms.unix;
    maintainers = [ ];
  };
}
