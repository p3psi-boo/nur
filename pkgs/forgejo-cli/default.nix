{
  lib,
  stdenv,
  zig_0_17,
  git,
  makeWrapper,
  installShellFiles,
  generated,
}:

let
  sourceInfo = generated.forgejo-cli;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "forgejo-cli";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  zigDeps = zig_0_17.fetchDeps {
    inherit (finalAttrs)
      pname
      version
      src
      ;
    hash = "sha256-A1n1h2pzgq/BDv3JYZ1bcJhPWAAL5O1nLw6qfRl4r6s=";
  };

  nativeBuildInputs = [
    zig_0_17.hook
    makeWrapper
    installShellFiles
  ];

  # pkgs/forgejo-cli is the NUR overlay attribute, so this replaces nixpkgs' forgejo-cli.
  postConfigure = ''
    ln -s ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  doCheck = false;

  # `fj completion` writes the script with std.debug.print, which lands on stderr.
  postInstall =
    ''
      wrapProgram "$out/bin/fj" --prefix PATH : ${lib.makeBinPath [ git ]}
    ''
    + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      export HOME=$(mktemp -d)
      installShellCompletion --cmd fj \
        --bash <("$out/bin/fj" completion bash 2>&1) \
        --fish <("$out/bin/fj" completion fish 2>&1) \
        --zsh <("$out/bin/fj" completion zsh 2>&1)
    '';

  meta = {
    description = "CLI application for interacting with Forgejo";
    homepage = "https://github.com/p3psi-boo/forgejo-cli";
    changelog = "https://github.com/p3psi-boo/forgejo-cli/commits/${sourceInfo.version}";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "fj";
    platforms = lib.platforms.unix;
  };
})
