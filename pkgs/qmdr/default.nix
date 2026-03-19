{
  lib,
  stdenv,
  generated ? null,
  fetchFromGitHub,
  runCommand,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  bun,
  sqlite,
}:

let
  pnpm = pnpm_10;
  sourceInfo =
    if generated != null && generated ? qmdr then
      generated.qmdr
    else
      rec {
        version = "1.0.3";
        src = fetchFromGitHub {
          owner = "uf-hy";
          repo = "qmdr";
          rev = "85a853b2fa4e5e21d6288988c3d15922d1d65c1d";
          hash = "sha256-hqt4FAw1rTd+ZYX0rgBDY9Z25muqmtw7qzXfk1h0d1I=";
        };
      };
  version = lib.removePrefix "v" sourceInfo.version;

  npmOs = builtins.elemAt (lib.splitString "-" stdenv.hostPlatform.system) 1;
  npmCpu =
    let
      arch = builtins.elemAt (lib.splitString "-" stdenv.hostPlatform.system) 0;
    in
    {
      x86_64 = "x64";
      aarch64 = "arm64";
      i686 = "ia32";
      armv7l = "arm";
    }
    .${arch} or arch;

  setPnpmArch = ''
    echo "supportedArchitectures.os=[\"${npmOs}\"]" >> .npmrc
    echo "supportedArchitectures.cpu=[\"${npmCpu}\"]" >> .npmrc
  '';

  srcWithLock = runCommand "qmdr-src-with-pnpm-lock-${version}" { } ''
    cp -r ${sourceInfo.src} $out
    chmod -R u+w $out

    sed -i '/"node-llama-cpp"/d' $out/package.json
    sed -i '/"sqlite-vec-win32-x64"/d' $out/package.json
    sed -i 's/"sqlite-vec-linux-x64": "\^0.1.7-alpha.2",/"sqlite-vec-linux-x64": "^0.1.7-alpha.2"/' $out/package.json
    sed -i \
      -e 's|"qmd": "src/qmd.ts"|"qmdr": "src/qmd.ts"|' \
      -e 's|"qmd": "bun src/qmd.ts"|"qmdr": "bun src/qmd.ts"|' \
      $out/package.json

    find $out/src -type f -name '*.ts' -exec sed -i \
      -e 's/QMD/QMDR/g' \
      -e 's/QMDRR/QMDR/g' \
      -e 's|qmd://|qmdr://|g' \
      -e 's|qmd:|qmdr:|g' \
      -e 's|~/.config/qmd|~/.config/qmdr|g' \
      -e 's|~/.cache/qmd|~/.cache/qmdr|g' \
      -e 's|resolve(cacheDir, "qmd")|resolve(cacheDir, "qmdr")|g' \
      -e 's|join(homedir(), ".config", "qmd")|join(homedir(), ".config", "qmdr")|g' \
      -e 's|join(homedir(), ".cache", "qmd", "models")|join(homedir(), ".cache", "qmdr", "models")|g' \
      -e 's/path = path.slice(4);/path = path.slice(5);/g' \
      -e 's/name: "qmd"/name: "qmdr"/g' \
      -e 's/本地 qmd-query-expansion/本地 query-expansion/g' \
      -e 's/qmd /qmdr /g' \
      {} +

    cp ${./pnpm-lock.yaml} $out/pnpm-lock.yaml
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "qmdr";
  inherit version;

  src = srcWithLock;

  pnpmDeps = (fetchPnpmDeps.override { inherit pnpm; }) {
    inherit (finalAttrs) pname version src;
    hash = "sha256-jbOKFlO/SF5n7XyZY5yk6tPgwsKM/BwIzi6LKPY6WD4=";
    fetcherVersion = 1;
    prePnpmInstall = setPnpmArch;
    NODE_ENV = "production";
  };

  prePnpmInstall = setPnpmArch;

  nativeBuildInputs = [
    bun
    pnpm
    (pnpmConfigHook.override { inherit pnpm; })
  ];

  buildInputs = [ sqlite ];

  NODE_ENV = "production";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/qmdr" "$out/bin"
    cp -r src "$out/lib/qmdr/src"
    cp -r node_modules "$out/lib/qmdr/node_modules"
    cp package.json "$out/lib/qmdr/package.json"

    cat > "$out/bin/qmdr" <<'EOF'
#!${stdenv.shell}
set -euo pipefail

alias_var() {
  local suffix="$1"
  local old="QMD_''${suffix}"
  local new="QMDR_''${suffix}"
  if [ -z "''${!new+x}" ] && [ -n "''${!old+x}" ]; then
    export "$new=''${!old}"
  fi
}

for suffix in \
  ALLOW_SQLITE_EXTENSIONS \
  SQLITE_VEC_PATH \
  CONFIG_DIR \
  LAUNCHD_PLIST \
  CHUNK_SIZE_TOKENS \
  CHUNK_OVERLAP_TOKENS \
  SILICONFLOW_API_KEY \
  GEMINI_API_KEY \
  OPENAI_API_KEY \
  DASHSCOPE_API_KEY \
  EMBED_PROVIDER \
  QUERY_EXPANSION_PROVIDER \
  RERANK_PROVIDER \
  RERANK_MODE \
  SILICONFLOW_LLM_RERANK_MODEL \
  LLM_RERANK_MODEL \
  SILICONFLOW_BASE_URL \
  SILICONFLOW_RERANK_MODEL \
  SILICONFLOW_MODEL \
  SILICONFLOW_EMBED_MODEL \
  SILICONFLOW_QUERY_EXPANSION_MODEL \
  GEMINI_BASE_URL \
  GEMINI_RERANK_MODEL \
  GEMINI_MODEL \
  OPENAI_BASE_URL \
  OPENAI_MODEL \
  OPENAI_EMBED_MODEL \
  DASHSCOPE_BASE_URL \
  DASHSCOPE_RERANK_MODEL \
  MAX_INDEX_FILE_BYTES \
  EMBED_BATCH_SIZE \
  RERANK_DOC_LIMIT \
  RERANK_CHUNKS_PER_DOC
 do
  alias_var "$suffix"
 done

export LD_LIBRARY_PATH="${sqlite.out}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DYLD_LIBRARY_PATH="${sqlite.out}/lib''${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

exec ${bun}/bin/bun "${placeholder "out"}/lib/qmdr/src/qmd.ts" "$@"
EOF
    chmod +x "$out/bin/qmdr"

    runHook postInstall
  '';

  meta = {
    description = "Remote-first CLI search engine for markdown docs, notes, and knowledge bases";
    homepage = "https://github.com/uf-hy/qmdr";
    license = lib.licenses.mit;
    mainProgram = "qmdr";
    platforms = lib.platforms.unix;
  };
})
