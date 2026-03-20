{
  lib,
  buildNpmPackage,
  generated,
  nodejs_22,
  makeWrapper,
  which,
}:

let
  sourceInfo = generated.liteparse;
in
buildNpmPackage (finalAttrs: {
  pname = "liteparse";
  version = lib.removePrefix "v" sourceInfo.version;
  inherit (sourceInfo) src;

  postPatch = ''
    # Upstream hardcodes an outdated CLI version string.
    substituteInPlace cli/parse.ts \
      --replace-fail '.version("0.1.0")' '.version("${finalAttrs.version}")'

    # PDF.js expects filesystem paths for bundled assets under Node.
    cat > src/engines/pdf/pdfjsImporter.ts <<'EOF'
import { fileURLToPath } from "node:url";

export async function importPdfJs() {
  const pdfDir = new URL("../../vendor/pdfjs/", import.meta.url);
  const pdfjs = await import(new URL("pdf.mjs", pdfDir).href);

  return {
    fn: pdfjs.getDocument,
    dir: fileURLToPath(pdfDir).replace(/\/$/, ""),
  };
}
EOF
  '';

  nodejs = nodejs_22;
  npmBuildScript = "build";
  npmDepsHash = "sha256-qy8DKTHeix8jPi0Fi0HLCAX3V9p0M5/snO1bfIkZLj0=";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/lit" \
      --prefix PATH : ${lib.makeBinPath [ which ]}
    wrapProgram "$out/bin/liteparse" \
      --prefix PATH : ${lib.makeBinPath [ which ]}
  '';

  meta = {
    description = "Fast local document parser with OCR and PDF screenshots";
    homepage = "https://github.com/run-llama/liteparse";
    downloadPage = "https://www.npmjs.com/package/@llamaindex/liteparse";
    license = lib.licenses.asl20;
    mainProgram = "lit";
    platforms = lib.platforms.unix;
  };
})
