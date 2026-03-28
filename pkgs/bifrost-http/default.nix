{
  buildGoModule,
  generated,
  go_1_26,
  lib,
  pkg-config,
  sqlite,
  bifrost-ui ? null,
}:

let
  sourceInfo = generated."bifrost-http";
  # Use version from source date or commit
  version = sourceInfo.date or "unstable-${builtins.substring 0 7 sourceInfo.version}";

  # Go module local replaces for monorepo structure
  transportsLocalReplaces = ''
    if [ -f transports/go.mod ]; then
      cat >> transports/go.mod <<'EOF'

    replace github.com/maximhq/bifrost/core => ../core
    replace github.com/maximhq/bifrost/framework => ../framework
    replace github.com/maximhq/bifrost/plugins/governance => ../plugins/governance
    replace github.com/maximhq/bifrost/plugins/litellmcompat => ../plugins/litellmcompat
    replace github.com/maximhq/bifrost/plugins/logging => ../plugins/logging
    replace github.com/maximhq/bifrost/plugins/maxim => ../plugins/maxim
    replace github.com/maximhq/bifrost/plugins/otel => ../plugins/otel
    replace github.com/maximhq/bifrost/plugins/semanticcache => ../plugins/semanticcache
    replace github.com/maximhq/bifrost/plugins/telemetry => ../plugins/telemetry
    EOF
    fi
  '';
in
(buildGoModule.override { go = go_1_26; }) (finalAttrs: {
  pname = "bifrost-http";
  inherit version;

  src = sourceInfo.src;

  modRoot = "transports";
  subPackages = [ "bifrost-http" ];

  # Vendor hash
  vendorHash = "sha256-T0L7ujWOmRnzovKvabh+cUmJ+MMla+TdnwlWAJLKwag=";

  doCheck = false;

  overrideModAttrs = final: prev: {
    postPatch = (prev.postPatch or "") + transportsLocalReplaces;
  };

  env = {
    CGO_ENABLED = "1";
    GOAMD64 = "v3";  # 即使使用 CGO 也可以启用指令集优化
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    sqlite
  ];

  postPatch = transportsLocalReplaces;

  preBuild = ''
    # Provide UI assets for //go:embed all:ui
    rm -rf bifrost-http/ui
    mkdir -p bifrost-http/ui
    if [ -n "${toString bifrost-ui}" ] && [ -d "${bifrost-ui}/ui" ]; then
      cp -R --no-preserve=mode,ownership,timestamps "${bifrost-ui}/ui/." bifrost-http/ui/
    else
      # Create a minimal index.html if no UI is provided
      printf '%s\n' '<!DOCTYPE html><html><head><title>Bifrost</title></head><body><h1>Bifrost</h1></body></html>' > bifrost-http/ui/index.html
    fi
  '';

  buildFlags = [ "-gcflags=all=-l=4" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  meta = {
    description = "High-performance AI gateway with unified API for 15+ providers";
    homepage = "https://github.com/maximhq/bifrost";
    license = lib.licenses.asl20;
    mainProgram = "bifrost-http";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})