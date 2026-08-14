{
  lib,
  rustPlatform,
  generated,
  pkg-config,
}:

let
  sourceInfo = generated.ironet;
in
rustPlatform.buildRustPackage {
  pname = "ironet";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  # Tests spawn the daemon and require /dev/net/tun + CAP_NET_ADMIN.
  doCheck = false;

  meta = {
    description = "Demand-aware Linux overlay network using iroh and a single FlowRouter TUN";
    homepage = "https://github.com/p3psi-boo/ironet";
    license = lib.licenses.mit; # MIT OR Apache-2.0
    mainProgram = "ironet";
    platforms = lib.platforms.linux;
  };
}
