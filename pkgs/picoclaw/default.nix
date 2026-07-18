{
  lib,
  buildGoModule,
  olm,
  generated,
}:

buildGoModule rec {
  pname = "picoclaw";
  version = generated.picoclaw.version;
  inherit (generated.picoclaw) src;
  vendorHash = "sha256-mN+eI8JtqIqBCxheVlTw7nL200WgVAd8xLhUsrYdohE=";

  # mautrix-go crypto backend links libolm via cgo. libolm is marked
  # insecure in nixpkgs (deprecated upstream, timing side-channels in
  # its AES/SHA primitives). Accepted here because Matrix is an optional
  # chat backend and the pure-Go goolm alternative is still experimental.
  buildInputs = [
    (olm.overrideAttrs (old: {
      meta = old.meta // { knownVulnerabilities = [ ]; };
    }))
  ];

  postPatch = ''
    # Unpin go version to match nixpkgs toolchain
    goVersion="$(go env GOVERSION)"
    goVersion="''${goVersion#go}"
    sed -i "s/^go .*/go $goVersion/" go.mod
    sed -i '/^toolchain /d' go.mod

    # go:embed in cmd/picoclaw/internal/onboard/command.go expects a workspace
    # directory copied there by go:generate which doesn't run during nix builds
    cp -r workspace cmd/picoclaw/internal/onboard/workspace
  '';

  subPackages = [ "cmd/picoclaw" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/sipeed/picoclaw/pkg/config.Version=${version}"
  ];

  # Tests require runtime configuration and network access
  doCheck = false;

  meta = {
    description = "Tiny, fast, and deployable anywhere — automate the mundane, unleash your creativity";
    homepage = "https://picoclaw.io";
    changelog = "https://github.com/sipeed/picoclaw/releases";
    license = lib.licenses.mit;
    mainProgram = "picoclaw";
    platforms = lib.platforms.unix;
  };
}
