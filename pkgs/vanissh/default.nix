{
  stdenv,
  lib,
  meson,
  ninja,
  pkg-config,
  libssh,
  openssl,
  generated,
}:

let
  sourceInfo = generated.vanissh;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "vanissh";
  version = sourceInfo.version;

  src = sourceInfo.src;

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    libssh
    openssl
  ];

  mesonFlags = [
    "-Denable_native=false" # 禁用 -march=native 以保证可重现性
    "-Denable_fast_math=true"
  ];

  meta = {
    description = "Generate vanity SSH public keys that start, contain, or end with specified strings";
    homepage = "https://github.com/k4yt3x/vanissh";
    license = lib.licenses.agpl3Only;
    maintainers = [ ];
    mainProgram = "vanissh";
    platforms = lib.platforms.unix;
  };
})
