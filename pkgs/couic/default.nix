{
  lib,
  rustPlatform,
  generated,
  bpf-linker,
}:

let
  sourceInfo = generated.couic;
in
rustPlatform.buildRustPackage {
  pname = "couic";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  cargoLock.lockFile = sourceInfo.src + "/Cargo.lock";

  # aya-build 0.1.3 shells out to `rustup run nightly cargo -Z build-std=core`.
  # nixpkgs rustc already ships libcore for bpfel-unknown-none, so drop rustup
  # and build-std and invoke cargo against the current toolchain instead.
  postPatch = ''
    rm -f rust-toolchain.toml

    ayaBuildLib=$(find "$cargoDepsCopy" -path '*/aya-build-*/src/lib.rs' -print -quit)
    if [ -z "$ayaBuildLib" ]; then
      echo "couic: aya-build sources not found under $cargoDepsCopy"
      find "$cargoDepsCopy" -name 'lib.rs' | head
      exit 1
    fi
    sed -i \
      -e 's/Command::new("rustup")/Command::new("cargo")/' \
      -e '/^[[:space:]]*"run",$/d' \
      -e '/toolchain.as_str(),/d' \
      -e '/^[[:space:]]*"cargo",$/d' \
      -e '/^[[:space:]]*"-Z",$/d' \
      -e '/build-std=core/d' \
      "$ayaBuildLib"
  '';

  env = {
    RUSTFLAGS = "-C target-feature=";
    RUSTC_BOOTSTRAP = 1;
  };

  nativeBuildInputs = [
    bpf-linker
  ];

  # Upstream release profile already uses opt-level=3 + LTO for the XDP path.
  # Integration tests need privileged Docker / XDP, so skip the test suite.
  doCheck = false;

  postInstall = ''
    rm -f $out/bin/mangen
    install -Dm644 configs/couic.toml $out/share/couic/couic.toml
    install -Dm644 configs/couicctl.toml $out/share/couic/couicctl.toml
    install -Dm644 configs/couic-report.toml $out/share/couic/couic-report.toml
  '';

  meta = {
    description = "Lightweight XDP-powered network filter controllable through a REST API";
    homepage = "https://github.com/FCSC-FR/couic";
    changelog = "https://github.com/FCSC-FR/couic/releases/tag/${sourceInfo.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "couic";
    platforms = lib.platforms.linux;
  };
}
