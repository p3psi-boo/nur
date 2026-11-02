{
  lib,
  buildGoModule,
  buildNpmPackage,
  generated,
}:

let
  sourceInfo = generated.mcpjungle;
  version = "0-unstable-${sourceInfo.date}";

  dashboard = buildNpmPackage {
    pname = "mcpjungle-dashboard";
    inherit version;
    inherit (sourceInfo) src;

    sourceRoot = "source/web/dashboard";
    npmDepsHash = "sha256-zvsMx6OxVIWj4krYInhp9jmUD0tiLqzpIiiSB8kVHqY=";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r dist/. "$out/"
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "mcpjungle";
  inherit version;
  inherit (sourceInfo) src;

  vendorHash = "sha256-3uatBXXdQzqGuhFuLkpmoMkYYqUMt1dFqm7vuazMLqs=";

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
  };

  preBuild = ''
    mkdir -p internal/dashboardui/dist
    cp -r ${dashboard}/. internal/dashboardui/dist/
  '';

  preCheck = ''
    # Upstream release builds use CGO for tests that import go-sqlite3, then
    # produce the final Linux binary with CGO disabled.
    export CGO_ENABLED=1
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    touch "$HOME/.keep"
  '';

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/mcpjungle/mcpjungle/pkg/version.Version=${version}"
  ];

  passthru = {
    inherit dashboard;
  };

  meta = {
    description = "Self-hosted gateway for managing and connecting to MCP servers";
    homepage = "https://github.com/p3psi-boo/MCPJungle";
    license = lib.licenses.mpl20;
    mainProgram = "mcpjungle";
    platforms = lib.platforms.unix;
  };
}
