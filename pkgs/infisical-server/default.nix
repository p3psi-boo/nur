{
  lib,
  stdenv,
  generated,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  python3,
  unixodbc,
  cacert,
  runCommand,
  postgresql_16,
  redis,
}:

let
  sourceInfo = generated.infisical-server;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "infisical-server";
  inherit (sourceInfo) version src;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    python3
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    unixodbc
  ];

  # Repackage the official native release, including its matching Node runtime
  # and native addons. Never execute Debian maintainer scripts or omnibus/runit.
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" unpacked
    sourceRoot=unpacked/opt/infisical-core
    runHook postUnpack
  '';
  dontConfigure = true;
  dontBuild = true;
  dontUpdateAutotoolsGnuConfigScripts = true;

  postPatch = ''
    python ${./prune.py} server
  '';

  installPhase = ''
    runHook preInstall
    app="$out/libexec/infisical-server"
    mkdir -p "$app" "$out/bin" "$out/share/licenses/infisical-server"
    cp -a server/{dist,frontend-build,node_modules,package.json,package-lock.json} "$app/"
    install -m755 embedded/bin/node "$app/node"
    cp -a LICENSE LICENSES licenses "$out/share/licenses/infisical-server/"
    cp server/dist/ee/LICENSE.md "$out/share/licenses/infisical-server/ENTERPRISE-LICENSE.md"

    # Keep node_modules/.bin usable without retaining npm, Ruby or Chef.
    ln -s "$app/node" "$app/node_modules/.bin/node"
    makeWrapper "$app/node" "$out/bin/infisical-server" \
      --chdir "$app" \
      --prefix PATH : "$app/node_modules/.bin" \
      --set-default NODE_ENV production \
      --set-default STANDALONE_MODE true \
      --set-default HOST 127.0.0.1 \
      --set-default PORT 8080 \
      --set-default INFISICAL_PLATFORM_VERSION "${finalAttrs.version}" \
      --set-default NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --add-flags "--enable-source-maps $app/dist/main.mjs"
    runHook postInstall
  '';

  # Vendor JS shebangs must resolve the matching runtime, not a build-time Node.
  postFixup = ''
    while IFS= read -r -d "" script; do
      if head -n1 "$script" | grep -qE '^#!.*(env node|/bin/node)'; then
        sed -i "1c#!$out/libexec/infisical-server/node" "$script"
      fi
    done < <(find "$out/libexec/infisical-server/node_modules" -type f -perm /111 -print0)
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    app="$out/libexec/infisical-server"
    "$app/node" --version
    cd "$app"
    "$app/node" -e '
      for (const name of ["argon2", "bcrypt", "re2", "pkcs11js", "odbc"]) {
        require(name);
      }
    '
    test -s frontend-build/index.html
    test -s dist/main.mjs
    runHook postInstallCheck
  '';

  passthru.tests.smoke =
    runCommand "infisical-server-smoke-test"
      {
        nativeBuildInputs = [
          finalAttrs.finalPackage
          python3
          postgresql_16
          redis
        ];
        # A local, unprivileged integration test; no Internet or real credentials.
      }
      ''
        python ${./smoke-test.py}
        touch "$out"
      '';

  meta = {
    description = "Infisical secrets-management server and Web UI (official native distribution)";
    homepage = "https://infisical.com";
    changelog = "https://github.com/Infisical/infisical/releases/tag/v${finalAttrs.version}";
    # The distribution includes MIT community code AND enterprise-licensed code.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    hydraPlatforms = [ ];
    mainProgram = "infisical-server";
  };
})
