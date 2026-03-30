{
  lib,
  rustPlatform,
  generated,
  stdenv,
  pkg-config,
  openssl,
  apple-sdk,
  fetchFromGitHub,
}:

let
  sourceInfo = generated.firm;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "firm";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  cargoHash = "sha256-+7oWC3QAoShB1FA0lwdOMOL0DH2eP2MOINEkrDkqTHg=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.isDarwin [
    apple-sdk
  ];

  # Optimize for runtime performance
  CARGO_BUILD_INCREMENTAL = "false";
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";
  CARGO_PROFILE_RELEASE_LTO = "thin";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_PANIC = "abort";

  # Build only the firm-cli binary from the workspace
  buildPhase = ''
    runHook preBuild
    cargo build --offline --profile release -p firm-cli
    runHook postBuild
  '';

  # Install the firm binary
  installPhase = ''
    runHook preInstall
    install -D -m 755 target/release/firm $out/bin/firm
    runHook postInstall
  '';

  # Skip tests for now
  doCheck = false;

  meta = with lib; {
    description = "A text-based work management system for technologists";
    homepage = "https://github.com/42futures/firm";
    changelog = "https://github.com/42futures/firm/blob/${src.rev}/CHANGES.md";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "firm";
  };
})
