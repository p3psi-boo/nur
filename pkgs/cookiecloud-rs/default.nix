{
  lib,
  rustPlatform,
  generated,
}:

rustPlatform.buildRustPackage {
  pname = "cookiecloud-rs";
  version = generated.cookiecloud-rs.version;
  src = generated.cookiecloud-rs.src;

  cargoLock.lockFile = ./Cargo.lock;

  # Monorepo: Rust project is in api-rs subdirectory
  postUnpack = ''
    sourceRoot=$(find . -maxdepth 1 -type d -name 'CookieCloud-*')/api-rs
    cp ${./Cargo.lock} "$sourceRoot/Cargo.lock"
  '';

  buildType = "release";
  doCheck = true;

  meta = {
    description = "Rust rewrite of CookieCloud API server with significantly lower resource usage";
    homepage = "https://github.com/p3psi-boo/CookieCloud/tree/master/api-rs";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "cookiecloud-api";
  };
}
