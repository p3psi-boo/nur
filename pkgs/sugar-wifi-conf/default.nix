{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  dbus,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "sugar-wifi-conf";
  version = "0-unstable-${generated.sugar-wifi-conf.date}";

  src = generated.sugar-wifi-conf.src;

  # The Rust crate lives in the `rust/` subdirectory of the monorepo.
  # setSourceRoot auto-detects the repo root; we descend into the crate.
  postUnpack = ''
    sourceRoot="$sourceRoot/rust"
  '';

  cargoHash = "sha256-MLsV7GPOpfuH/kgwGlayHxluP5Y73e6zwROhPkWUKBg=";

  # bluer links libdbus-1 and discovers it via pkg-config.
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus ];

  buildType = "release";
  doCheck = false; # crate ships no test harness

  meta = {
    description = "BLE service to configure WiFi over Bluetooth, with an SSH-over-BLE tunnel (PiSugar)";
    homepage = "https://github.com/PiSugar/sugar-wifi-conf";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "sugar-wifi-conf";
  };
})
