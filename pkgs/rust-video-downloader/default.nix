{
  lib,
  rustPlatform,
  generated,
  ffmpeg,
  makeWrapper,
}:

rustPlatform.buildRustPackage rec {
  pname = "rust-video-downloader";
  version = generated.rust-video-downloader.version;
  src = generated.rust-video-downloader.src;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  postPatch = ''
    # Copy Cargo.lock to source directory since it's not in the repository
    cp ${./Cargo.lock} Cargo.lock
  '';

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ ffmpeg ];

  # Optimize for size
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_LTO = "fat";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "z";

  postInstall = ''
    wrapProgram $out/bin/rvd \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]}
  '';

  stripAllList = [ "bin" ];

  meta = {
    description = "High-performance modular cross-platform video downloader";
    homepage = "https://github.com/SpenserCai/rust-video-downloader";
    license = lib.licenses.mit;
    mainProgram = "rvd";
    maintainers = [ ];
  };
}
