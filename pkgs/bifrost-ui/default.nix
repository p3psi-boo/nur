{
  buildNpmPackage,
  generated,
  lib,
}:

let
  sourceInfo = generated."bifrost-ui";
  version = "0-unstable-2026-03-29";
in
buildNpmPackage {
  pname = "bifrost-ui";
  inherit version;
  inherit (sourceInfo) src;

  # Work in the ui subdirectory
  prePatch = ''
    cd ui
  '';

  # NPM deps hash
  npmDepsHash = "sha256-HGPGv9FwdhGo/ZubBlApinTtLbKkdrmENfdjkxc+iiQ=";

  # Next's `next/font/google` requires network access at build time.
  # Nix builds are sandboxed (no network), so patch the layout to avoid
  # fetching Google Fonts.
  postPatch = ''
    cat > app/layout.tsx <<'EOF'
    import "./globals.css"

    export default function RootLayout({ children }: { children: React.ReactNode }) {
      return (
        <html>
          <body>{children}</body>
        </html>
      )
    }
    EOF
  '';

  # Avoid the upstream build script's copy step (writes outside $PWD).
  npmBuildScript = "build-enterprise";
  env.NEXT_TELEMETRY_DISABLED = "1";
  env.NEXT_DISABLE_ESLINT = "1";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/ui"
    cp -R --no-preserve=mode,ownership,timestamps out/. "$out/ui/"

    runHook postInstall
  '';

  meta = {
    description = "Bifrost web UI for AI gateway configuration and monitoring";
    homepage = "https://github.com/maximhq/bifrost";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}