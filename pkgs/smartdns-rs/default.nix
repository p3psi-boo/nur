{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  clang,
}:

let
  sourceInfo = generated.smartdns-rs;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "smartdns-rs";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
    outputHashes = {
      "async-socks5-0.6.0" = "sha256-jbVwQW43vRMFsejwS6F9fcpAWTcKiTYFWM0/0o7s6/g=";
      "hickory-proto-0.26.0-alpha.1" = "sha256-4ZAPL6OLXB2ewQXoD+cfXJHq7TVWyJQWcy5Na1LFNP8=";
      "hickory-resolver-0.26.0-alpha.1" = "sha256-4ZAPL6OLXB2ewQXoD+cfXJHq7TVWyJQWcy5Na1LFNP8=";
      "rustls-pki-types-1.12.0" = "sha256-RjHCYfHXpIT5IV3tuykMhAcUhBlPPrWZ7NgXOdQY6mg=";
      "self_update-0.42.0" = "sha256-cS3PTFE3gFnVuBsGusEzAOqKqhXMt7zM6p+zXDnajy0=";
      "surge-ping-0.8.2" = "sha256-raNzf3VAotbUe5aXkxoyglkEq3jijycgiWJSPRJK+eU=";
      "utoipa-5.3.1" = "sha256-AH19Jn6jtKn53vloTDwx710g4SDvdwr8HTDRntghIe4=";
      "utoipa-axum-0.2.0" = "sha256-AH19Jn6jtKn53vloTDwx710g4SDvdwr8HTDRntghIe4=";
      "utoipa-gen-5.3.1" = "sha256-AH19Jn6jtKn53vloTDwx710g4SDvdwr8HTDRntghIe4=";
    };
  };

  nativeBuildInputs = [
    pkg-config
    clang
    rustPlatform.bindgenHook
  ];

  cargoBuildFlags = [
    "--no-default-features"
    "--features"
    "common"
  ];

  cargoTestFlags = finalAttrs.cargoBuildFlags;

  postPatch = ''
    substituteInPlace build.rs \
      --replace-fail 'download_resources()?;' '// download_resources()?;'
  '';

  postInstall = ''
    install -Dm644 etc/smartdns/smartdns.conf "$out/etc/smartdns/smartdns.conf"
  '';

  doCheck = false;

  meta = {
    description = "Cross-platform local DNS server written in Rust";
    homepage = "https://github.com/mokeyish/smartdns-rs";
    license = lib.licenses.gpl3Only;
    mainProgram = "smartdns";
    platforms = lib.platforms.linux;
  };
})
