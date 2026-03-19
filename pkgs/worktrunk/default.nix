{
  lib,
  rustPlatform,
  generated,
  installShellFiles,
  makeBinaryWrapper,
  git,
}:

rustPlatform.buildRustPackage rec {
  pname = "worktrunk";
  version = generated.worktrunk.version;
  src = generated.worktrunk.src;

  cargoHash = "sha256-abzDnqi3i0Mt+CohoUdqrMqoUMCZTgHIyKLQBtywRmk=";

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
  ];

  # Tests require some setup, and potentially PTY (though tier-2 tests are disabled by default)
  doCheck = false;

  # Optimize for binary size (see docs/min-sized-rust.md)
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "z";
  CARGO_PROFILE_RELEASE_LTO = "true";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_PANIC = "abort";

  # Strip all symbols (not just debug symbols)
  stripAllList = [ "bin" ];

  postInstall = ''
    wrapProgram $out/bin/wt \
      --prefix PATH : ${lib.makeBinPath [ git ]}

    installShellCompletion --cmd wt \
      --bash <(COMPLETE=bash $out/bin/wt) \
      --fish <(COMPLETE=fish $out/bin/wt) \
      --zsh <(COMPLETE=zsh $out/bin/wt)
  '';

  meta = with lib; {
    description = "A CLI for Git worktree management, designed for parallel AI agent workflows";
    homepage = "https://github.com/max-sixty/worktrunk";
    license = with licenses; [
      mit
      asl20
    ];
    mainProgram = "wt";
  };
}
