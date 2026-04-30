{
  lib,
  generated,
  fetchFromGitHub,
  runCommand,
  cmake,
  ninja,
  pkg-config,
  makeWrapper,
  autoAddDriverRunpath,
  cudaPackages,
  python313,
}:

let
  sourceInfo = generated.lucebox-hub;
  version = "0-unstable-${sourceInfo.date}";

  # Keep the packaged scope on the dflash runtime because the repository root is
  # only a document hub and the megakernel subtree is a separate PyTorch/CUDA
  # extension without a lockfile or packaging metadata.
  llamaCppSrc = fetchFromGitHub {
    owner = "Luce-Org";
    repo = "llama.cpp";
    rev = "1823460262950917e7ddcf65040295b41a423c55";
    hash = "sha256-IaSju4OSO6UDtTxBiC+h8rIw0hDzYZMDcHDN90yPupo=";
  };

  workspaceRoot = runCommand "lucebox-hub-workspace-${version}" { } ''
    cp -r ${sourceInfo.src} "$out"
    chmod -R u+w "$out"

    # nvfetcher currently materializes the root repo without the pinned
    # submodule, so inject the exact llama.cpp tree that dflash expects.
    mkdir -p "$out/dflash/deps/llama.cpp"
    cp -r ${llamaCppSrc}/. "$out/dflash/deps/llama.cpp"
  '';

  effectiveStdenv = cudaPackages.backendStdenv;
  cudaBuildInputs = with cudaPackages; [
    cuda_cccl
    cuda_cudart
    libcublas
  ];

  python = python313.override {
    packageOverrides = final: prev: {
      # Prevent Hugging Face's test-only torch path from pulling Triton into a runtime-only wrapper closure.
      safetensors = prev.safetensors.overridePythonAttrs (_: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });
    };
  };

  pythonEnv = python.withPackages (
    ps: with ps; [
      datasets
      fastapi
      jinja2
      pydantic
      sentencepiece
      transformers
      uvicorn
    ]
  );
in
effectiveStdenv.mkDerivation {
  pname = "lucebox-hub";
  inherit version;

  src = workspaceRoot;

  postUnpack = ''
    sourceRoot="$sourceRoot/dflash"
  '';

  nativeBuildInputs = [
    autoAddDriverRunpath
    cmake
    cudaPackages.cuda_nvcc
    makeWrapper
    ninja
    pkg-config
    python
  ];

  buildInputs = cudaBuildInputs;

  patches = [
    ./patches/0001-dflash-runtime-env-overrides.patch
  ];

  configurePhase = ''
    runHook preConfigure

    cmake -B build -S . \
      -G Ninja \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CUDA_ARCHITECTURES=86

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    cmake --build build --target test_dflash test_generate -j''${NIX_BUILD_CORES:-1}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/lucebox-hub" "$out/share/doc/lucebox-hub"

    install -Dm755 build/test_dflash "$out/libexec/lucebox-hub/test_dflash"
    install -Dm755 build/test_generate "$out/libexec/lucebox-hub/test_generate"

    cp -r scripts "$out/libexec/lucebox-hub/"
    cp -r examples "$out/libexec/lucebox-hub/"

    install -Dm644 README.md "$out/share/doc/lucebox-hub/dflash-README.md"
    install -Dm644 ../README.md "$out/share/doc/lucebox-hub/README.md"
    install -Dm644 ../megakernel/README.md "$out/share/doc/lucebox-hub/megakernel-README.md"

    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/lucebox-hub-run" \
      --set DFLASH_BIN "$out/libexec/lucebox-hub/test_dflash" \
      --add-flags "$out/libexec/lucebox-hub/scripts/run.py"

    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/lucebox-hub-server" \
      --set DFLASH_BIN "$out/libexec/lucebox-hub/test_dflash" \
      --add-flags "$out/libexec/lucebox-hub/scripts/server.py"

    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/lucebox-hub-chat" \
      --set DFLASH_BIN "$out/libexec/lucebox-hub/test_dflash" \
      --add-flags "$out/libexec/lucebox-hub/examples/chat.py"

    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/lucebox-hub-bench-he" \
      --set DFLASH_BIN "$out/libexec/lucebox-hub/test_dflash" \
      --add-flags "$out/libexec/lucebox-hub/scripts/bench_he.py"

    makeWrapper ${pythonEnv}/bin/python3 "$out/bin/lucebox-hub-bench-llm" \
      --set DFLASH_BIN "$out/libexec/lucebox-hub/test_dflash" \
      --set DFLASH_BIN_AR "$out/libexec/lucebox-hub/test_generate" \
      --add-flags "$out/libexec/lucebox-hub/scripts/bench_llm.py"

    ln -s "$out/libexec/lucebox-hub/test_dflash" "$out/bin/lucebox-hub-dflash"
    ln -s "$out/libexec/lucebox-hub/test_generate" "$out/bin/lucebox-hub-generate"

    runHook postInstall
  '';

  enableParallelBuilding = true;
  doCheck = false;

  meta = {
    description = "CUDA-only dflash runtime and helper scripts from Lucebox Hub";
    homepage = "https://github.com/Luce-Org/lucebox-hub";
    license = lib.licenses.mit;
    mainProgram = "lucebox-hub-run";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
}
