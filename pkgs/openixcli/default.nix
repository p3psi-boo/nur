{
  lib,
  rustPlatform,
  fetchFromGitHub,
  generated,
  pkg-config,
  libusb1,
}:

let
  sourceInfo = generated.openixcli;
  libefexSrc = fetchFromGitHub {
    owner = "YuzukiTsuru";
    repo = "libefex";
    rev = "828583afa2783c2746235bf69b5355f18898484e";
    hash = "sha256-gAEMYSHrAs0C8MrYMjiEsjdnBKybDaIJ44+jA9CnJEE=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "openixcli";
  version = sourceInfo.version;

  src = sourceInfo.src;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "libefex-0.1.0" = "sha256-gAEMYSHrAs0C8MrYMjiEsjdnBKybDaIJ44+jA9CnJEE=";
      "libefex-sys-0.1.0" = "sha256-gAEMYSHrAs0C8MrYMjiEsjdnBKybDaIJ44+jA9CnJEE=";
    };
  };

  # libefex-sys's build.rs expects the libefex repo root layout:
  # - ./src (C sources)
  # - ./includes (headers)
  # When vendored via Nix, the git dependency may only contain ./rust/.
  preBuild = ''
    rm -rf /build/src /build/includes
    ln -s "${libefexSrc}/src" /build/src
    ln -s "${libefexSrc}/includes" /build/includes
  '';

  postUnpack = ''
    cp ${./Cargo.lock} "$sourceRoot/Cargo.lock"
  '';

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libusb1 ];

  CARGO_BUILD_INCREMENTAL = "false";
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "z";
  CARGO_PROFILE_RELEASE_LTO = "true";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
  CARGO_PROFILE_RELEASE_PANIC = "abort";

  stripAllList = [ "bin" ];

  meta = {
    description = "CLI tool for flashing Allwinner firmware to devices";
    homepage = "https://github.com/YuzukiTsuru/OpenixCLI";
    license = lib.licenses.mit;
    mainProgram = "openixcli";
    platforms = lib.platforms.linux;
  };
}
