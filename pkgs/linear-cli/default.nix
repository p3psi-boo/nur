{
  lib,
  stdenvNoCC,
  deno,
  python3,
  cacert,
  makeWrapper,
  git,
  libsecret,
  generated,
}:

let
  sourceInfo = generated.linear-cli;
  version = lib.removePrefix "v" sourceInfo.version;
  prepare = "${python3}/bin/python3 ${./prepare.py}";

  # Only this fixed-output derivation accesses dependency registries. The
  # application and its GraphQL code are built offline in the regular sandbox.
  buildDeps = stdenvNoCC.mkDerivation {
    pname = "linear-cli-deno-deps";
    inherit version;
    src = sourceInfo.src;
    nativeBuildInputs = [
      deno
      cacert
      python3
    ];
    postPatch = "${prepare} build";
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR/home" DENO_DIR="$TMPDIR/deno-cache"
      export DENO_NO_UPDATE_CHECK=1
      mkdir -p "$HOME"
      deno install --frozen --node-modules-dir=none
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r "$DENO_DIR/npm" "$DENO_DIR/remote" "$out/"
      python3 ${./normalize-cache.py} "$out" deno.lock
      runHook postInstall
    '';
    dontFixup = true;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-qT7pRH/a487OFssIHAv+fCs3XkBg/hXl/YIsLjYE9K0=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "linear-cli";
  inherit version;
  src = sourceInfo.src;
  nativeBuildInputs = [
    deno
    python3
    makeWrapper
    git
  ];
  postPatch = "${prepare} build";
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR/home" DENO_DIR="$TMPDIR/deno-cache"
    export DENO_NO_UPDATE_CHECK=1 NO_COLOR=1
    mkdir -p "$HOME"
    cp -r ${buildDeps} "$DENO_DIR"
    chmod -R u+w "$DENO_DIR"
    deno run --cached-only --frozen -A npm:@graphql-codegen/cli/graphql-codegen-esm
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    deno test --cached-only --frozen --no-check -A test/main_test.ts test/credentials.test.ts test/keyring.test.ts
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    deno transpile --no-config --no-lock --outdir transpiled \
      $(find src -name '*.ts' ! -name '*.test.ts')
    ${prepare} runtime
    # Offline lockfile pruning, not a dependency update: all versions were
    # resolved from the upstream lockfile in the fixed-output build cache.
    deno install --cached-only --frozen=false --node-modules-dir=none
    deno info --json src/main.ts > runtime-graph.json

    app="$out/share/linear-cli"
    mkdir -p "$app" "$out/bin"
    python3 ${./runtime-cache.py} runtime-graph.json "$DENO_DIR" "$app/cache"
    cp -r src deno.json deno.lock "$app/"
    install -Dm644 LICENSE "$out/share/licenses/linear-cli/LICENSE"
    makeWrapper ${lib.getExe deno} "$out/bin/linear" \
      --set DENO_DIR "$app/cache" \
      --set DENO_NO_UPDATE_CHECK 1 \
      ${lib.optionalString stdenvNoCC.hostPlatform.isLinux "--prefix PATH : ${lib.makeBinPath [ libsecret ]}"} \
      --add-flags "run --quiet --cached-only --frozen --no-check -A --config $app/deno.json $app/src/main.ts"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/clean-home"
    mkdir -p "$HOME"
    "$out/bin/linear" --version | grep -Fx 'linear ${version}'
    "$out/bin/linear" --help > /dev/null
    "$out/bin/linear" markdown > /dev/null
    "$out/bin/linear" completions bash > /dev/null
    python3 ${./smoke-test.py} "$out/bin/linear" ${lib.getExe deno}
    # Install checks may write disposable caches before the store is sealed.
    # Keep only immutable dependency contents, not V8/SQLite/build-path caches.
    python3 - "$out/share/linear-cli/cache" <<'PY'
    import pathlib
    import shutil
    import sys
    for path in pathlib.Path(sys.argv[1]).iterdir():
        if path.name not in {"npm", "remote"}:
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            else:
                path.unlink()
    PY
    runHook postInstallCheck
  '';

  disallowedReferences = [
    buildDeps
    python3
    git
  ];

  passthru = { inherit buildDeps; };

  meta = {
    description = "Command-line client for the Linear issue tracker";
    homepage = "https://github.com/schpet/linear-cli";
    changelog = "https://github.com/schpet/linear-cli/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "linear";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
