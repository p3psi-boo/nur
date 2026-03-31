{
  lib,
  rustPlatform,
  generated,
}:

rustPlatform.buildRustPackage {
  pname = "vgpu_unlock-rs";
  version = generated.vgpu_unlock-rs.version;
  src = generated.vgpu_unlock-rs.src;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  postUnpack = ''
    cp ${./Cargo.lock} "$sourceRoot/Cargo.lock"
  '';

  doCheck = false;

  meta = with lib; {
    description = "Rust-based preload library for unlocking NVIDIA vGPU functionality on consumer GPUs";
    homepage = "https://github.com/rbqvq/vgpu_unlock-rs";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
