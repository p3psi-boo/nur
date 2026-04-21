{
  lib,
  autoAddDriverRunpath,
  cmake,
  fetchFromGitHub,
  installShellFiles,
  stdenv,
  cudaPackages,
  fetchNpmDeps,
  nodejs,
  npmHooks,
  pkg-config,
  openssl,
  ninja,
  generated,
}:

let
  # CUDA-only deployment target.
  cudaSupport = true;

  # Pin kernels to RTX 30 series (Ampere, sm_86) for reproducible binaries.
  cudaArchitectures = "86";

  effectiveStdenv = cudaPackages.backendStdenv;

  inherit (lib)
    cmakeBool
    cmakeFeature
    ;

  cudaBuildInputs = with cudaPackages; [
    cuda_cccl
    cuda_cudart
    libcublas
  ];
in

effectiveStdenv.mkDerivation (finalAttrs: {
  pname = "llama-cpp-turboquant";
  version = generated.llama-cpp-turboquant.version;

  outputs = [
    "out"
    "dev"
  ];

  src = generated.llama-cpp-turboquant.src;

  # Fix "invalid use of 'extern' in linkage specification" with GCC:
  # extern "C" + GGML_API (which expands to __attribute__(...) extern) is illegal.
  postPatch = ''
    sed -i 's/extern "C" GGML_API/GGML_API/g' ggml/src/ggml-cpu/ops.cpp
  '';

  nativeBuildInputs = [
    cmake
    installShellFiles
    ninja
    nodejs
    npmHooks.npmConfigHook
    pkg-config
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];

  buildInputs = cudaBuildInputs ++ [ openssl ];

  npmRoot = "tools/server/webui";

  npmDepsHash = "sha256-DxgUDVr+kwtW55C4b89Pl+j3u2ILmACcQOvOBjKWAKQ=";

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src;
    preBuild = ''
      pushd ${finalAttrs.npmRoot}
    '';
    hash = finalAttrs.npmDepsHash;
  };

  preConfigure = ''
    pushd ${finalAttrs.npmRoot}
    npm run build
    popd
  '';

  cmakeFlags = [
    (cmakeBool "GGML_NATIVE" false)
    (cmakeBool "LLAMA_BUILD_EXAMPLES" false)
    (cmakeBool "LLAMA_BUILD_SERVER" true)
    (cmakeBool "LLAMA_BUILD_TESTS" (finalAttrs.finalPackage.doCheck or false))
    (cmakeBool "LLAMA_OPENSSL" true)
    (cmakeBool "BUILD_SHARED_LIBS" true)
    (cmakeBool "GGML_CUDA" true)
    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaArchitectures)
  ];

  postInstall = ''
    mkdir -p $out/include
    cp $src/include/llama.h $out/include/
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd llama-server --bash <($out/bin/llama-server --completion-bash)
  '';

  enableParallelBuilding = true;

  doCheck = false;

  meta = {
    description = "llama.cpp fork with TurboQuant PlanarQuant KV cache (CUDA-optimized)";
    homepage = "https://github.com/johndpope/llama-cpp-turboquant";
    license = lib.licenses.mit;
    mainProgram = "llama-server";
    platforms = lib.platforms.linux;
    badPlatforms = lib.platforms.darwin;
  };
})
