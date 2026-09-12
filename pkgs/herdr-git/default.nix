{
  lib,
  stdenv,
  rustPlatform,
  zig_0_16,
  installShellFiles,
  cctools,
  xcbuild,
  generated,
}:

let
  sourceInfo = generated.herdr-git;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr";
  version = "0-unstable-${sourceInfo.date}";

  __structuredAttrs = true;

  src = sourceInfo.src;

  cargoLock.lockFile = sourceInfo.src + "/Cargo.lock";

  zigDeps = zig_0_16.fetchDeps {
    inherit (finalAttrs) pname version;
    src = "${finalAttrs.src}/vendor/libghostty-vt";
    fetchAll = true;
    hash = "sha256-Cy0DdSvce+fhOFIfxHMQGF2b2j16UkS27UpGbfC42XI=";
  };

  nativeBuildInputs = [
    zig_0_16.hook
    installShellFiles
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools
    xcbuild
  ];

  doCheck = false;

  dontUseZigBuild = true;
  dontUseZigCheck = true;
  dontUseZigInstall = true;

  postConfigure = ''
    export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
    cp -rL ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
    chmod -R u+w "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  postInstall = ''
    mkdir --parents "$out"/share/herdr/skills/herdr
    "$out"/bin/herdr --skill > "$_"/SKILL.md
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd herdr \
      --bash <("$out/bin/herdr" completion bash) \
      --fish <("$out/bin/herdr" completion fish) \
      --zsh <("$out/bin/herdr" completion zsh)
  '';

  meta = {
    description = "Agent multiplexer that lives in your terminal";
    homepage = "https://herdr.dev";
    changelog = "https://github.com/herdrdev/herdr/commits/${sourceInfo.version}";
    license = lib.licenses.asl20;
    mainProgram = "herdr";
    platforms = lib.platforms.unix;
  };
})
