{
  lib,
  rustPlatform,
  buildNpmPackage,
  importNpmLock,
  generated,
}:

let
  sourceInfo = generated.selector4nix;

  # Frontend (Vite/React) built as an npm package; its dist is symlinked into
  # the Rust build so crates/selector4nix-web/build.rs finds frontend/dist/.
  frontendDist = buildNpmPackage {
    pname = "selector4nix-frontend";
    version = sourceInfo.version;

    src = sourceInfo.src;

    npmDeps = importNpmLock {
      npmRoot = sourceInfo.src;
    };

    npmConfigHook = importNpmLock.npmConfigHook;

    installPhase = ''
      mkdir -p $out/lib/node_modules/selector4nix-frontend/frontend/
      cp -r frontend/dist $out/lib/node_modules/selector4nix-frontend/frontend/
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "selector4nix";
  version = sourceInfo.version;

  src = sourceInfo.src;

  cargoLock.lockFile = sourceInfo.src + "/Cargo.lock";

  postPatch = ''
    ln -s ${frontendDist}/lib/node_modules/selector4nix-frontend/frontend/dist frontend/dist
  '';

  cargoBuildFlags = [
    "-p"
    "selector4nix"
  ];

  cargoInstallFlags = [
    "-p"
    "selector4nix"
  ];

  cargoTestFlags = [
    "-p"
    "selector4nix"
  ];

  meta = {
    description = "Nix substituter proxy with parallel cache queries and latency-aware selection";
    homepage = "https://github.com/p3psi-boo/selector4nix";
    license = lib.licenses.gpl3Plus;
    mainProgram = "selector4nix";
    platforms = lib.platforms.unix;
  };
}
