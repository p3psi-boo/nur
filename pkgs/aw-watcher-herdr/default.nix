{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.aw-watcher-herdr;
in
buildGoModule {
  pname = "aw-watcher-herdr";
  version = "0-unstable-${sourceInfo.date}";
  src = sourceInfo.src;

  vendorHash = null;
  subPackages = [ "." ];
  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
  ];

  # The upstream tests use loopback HTTP servers and temporary Unix sockets.
  __darwinAllowLocalNetworking = true;

  postInstall = ''
    install -Dm644 README.md "$out/share/doc/aw-watcher-herdr/README.md"
  '';

  meta = {
    description = "Record local Herdr focus and agent status in ActivityWatch";
    homepage = "https://github.com/p3psi-boo/aw-watcher-herdr";
    changelog = "https://github.com/p3psi-boo/aw-watcher-herdr/commits/${sourceInfo.version}";
    # Upstream has not declared a license.
    license = lib.licenses.unfree;
    mainProgram = "aw-watcher-herdr";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
