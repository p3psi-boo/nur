{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "beads";
  version = "0.29.0";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${finalAttrs.version}";
    hash = "sha256-tS30cWkvrWm6MwMlGPup8dsB4Y53w+jqF8+rX8zwK9Q=";
  };

  vendorHash = "sha256-iTPi8+pbKr2Q352hzvIOGL2EneF9agrDmBwTLMUjDBE=";

  # Build from cmd/bd subdirectory
  subPackages = [ "cmd/bd" ];

  # Tests require git which we don't need for building
  doCheck = false;

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
  ];

  postInstall = ''
    mv $out/bin/bd $out/bin/beads
    ln -s $out/bin/beads $out/bin/bd
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Lightweight memory system for AI coding agents - distributed issue tracker backed by Git";
    homepage = "https://github.com/steveyegge/beads";
    changelog = "https://github.com/steveyegge/beads/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "beads";
  };
})
