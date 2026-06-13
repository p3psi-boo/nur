{
  lib,
  buildNpmPackage,
  python3,
  makeWrapper,
  nodejs,
  pkgs,
  libsecret,
  sqlite,
  generated,
}:

let
  sourceInfo = generated.omniroute;
  version = lib.removePrefix "v" sourceInfo.version;
  pname = "omniroute";
  src = sourceInfo.src;
  npmDepsHash = "sha256-gOvmN//owmxDIv9PzBbVNWkiIK5t9SLTLchD2VwdGFU=";
  patchPackageLock = ''
    if [ -f package-lock.json ]; then
      ${pkgs.jq}/bin/jq '.packages["node_modules/onnxruntime-node"].scripts = {"install": "echo skip"}' package-lock.json > package-lock.json.tmp
      mv package-lock.json.tmp package-lock.json
    fi
  '';
  patchGoogleFonts = ''
    if [ -f src/app/layout.tsx ]; then
      substituteInPlace src/app/layout.tsx \
        --replace-fail 'import { Inter } from "next/font/google";' "" \
        --replace-fail 'const inter = Inter({' 'const inter = { variable: "" } as any; /* skipped: Inter({' \
        --replace-fail '  subsets: ["latin"],' "*/" \
        --replace-fail '  variable: "--font-inter",' "" \
        --replace-fail '});' "" || true
    fi
  '';
in
buildNpmPackage {
  inherit pname version src npmDepsHash;

  postPatch = patchPackageLock + "\n" + patchGoogleFonts;

  npmDeps = pkgs.fetchNpmDeps {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = npmDepsHash;
    nativeBuildInputs = [ pkgs.jq ];
    postPatch = patchPackageLock;
  };

  npmRebuildFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    python3
    makeWrapper
    pkgs."pkg-config"
    pkgs.jq
  ];

  buildInputs = [
    nodejs
    libsecret
    sqlite
  ];

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/omniroute
    cp -r . $out/lib/omniroute
    makeWrapper ${nodejs}/bin/node $out/bin/omniroute \
      --add-flags "$out/lib/omniroute/bin/omniroute.mjs"
    runHook postInstall
  '';

  meta = {
    description = "Free AI gateway: one endpoint, 160+ providers";
    homepage = "https://github.com/diegosouzapw/OmniRoute";
    license = lib.licenses.mit;
    mainProgram = "omniroute";
    platforms = lib.platforms.linux;
  };
}
