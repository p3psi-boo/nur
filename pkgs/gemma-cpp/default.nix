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
  # Keep this package aligned with the CUDA-only deployment target.
  cudaSupport = true;

  # Pin kernels to RTX 30 series (Ampere, sm_86) for reproducible binaries.
  cudaArchitectures = "86";

  # Use CUDA backend stdenv
  effectiveStdenv = cudaPackages.backendStdenv;

  inherit (lib)
    cmakeBool
    cmakeFeature
    ;

  cudaBuildInputs = with cudaPackages; [
    cuda_cccl # <nv/target>
    cuda_cudart
    libcublas
  ];
in

effectiveStdenv.mkDerivation (finalAttrs: {
  pname = "gemma-cpp";
  version = "0-unstable-${generated.gemma-cpp.date}";

  outputs = [
    "out"
    "dev"
  ];

  src = generated.gemma-cpp.src;

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
    # -march=native is non-deterministic
    (cmakeBool "GGML_NATIVE" false)
    (cmakeBool "LLAMA_BUILD_EXAMPLES" false)
    (cmakeBool "LLAMA_BUILD_SERVER" true)
    (cmakeBool "LLAMA_BUILD_TESTS" (finalAttrs.finalPackage.doCheck or false))
    (cmakeBool "LLAMA_OPENSSL" true)
    (cmakeBool "BUILD_SHARED_LIBS" true)
    # Keep CUDA enabled unconditionally for this package.
    (cmakeBool "GGML_CUDA" true)
    # Pin generated kernels to RTX 30 series (Ampere, sm_86).
    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaArchitectures)
  ];

  postInstall = ''
    # Match binary name
    ln -sf $out/bin/llama-cli $out/bin/gemma
    ln -sf $out/bin/llama-server $out/bin/gemma-server
    mkdir -p $out/include
    cp $src/include/llama.h $out/include/
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd gemma-server --bash <($out/bin/gemma-server --completion-bash)
  '';

  # Skip tests
  doCheck = false;

  meta = {
    description = "llama.cpp fork with TurboQuant for Gemma 4 (CUDA-optimized)";
    homepage = "https://github.com/test1111111111111112/llama-cpp-turboquant-gemma4";
    license = lib.licenses.mit;
    mainProgram = "gemma";
    platforms = lib.platforms.linux;
    # CUDA only
    badPlatforms = lib.platforms.darwin;
  };
})
