{
  lib,
  rustPlatform,
  generated,
  pkg-config,
  cmake,
  perl,
  gitMinimal,
  symlinkJoin,
  cudaPackages,
  autoAddDriverRunpath,
}:

let
  sourceInfo = generated.deepseek-ocr-rs;

  # CUDA-only build target. Pin kernels to RTX 30 series (Ampere, sm_86) for
  # reproducible binaries, consistent with other CUDA packages in this repo
  # (gemma-cpp, llama-cpp-turboquant, lucebox-hub).
  cudaArchitecture = "86";

  # cudarc / candle-kernels' build scripts (via bindgen_cuda) probe a single
  # CUDA root and require both `include/cuda.h` and `bin/nvcc` to be present.
  # Compose a merged tree from the split nixpkgs cudaPackages outputs.
  cudaRoot = symlinkJoin {
    name = "cuda-merged-for-deepseek-ocr-rs";
    paths = with cudaPackages; [
      cuda_nvcc
      cuda_cudart
      cuda_cccl
      libcublas
      libcublas.dev
      libcublas.lib
      libcublas.include
      libcurand
      libcurand.dev
      libcurand.lib
      libcurand.include
      cuda_nvrtc
      cuda_nvrtc.dev
      cuda_nvrtc.lib
      cuda_nvrtc.include
    ];
  };

  cudaBuildInputs = with cudaPackages; [
    cuda_cudart
    cuda_cccl
    libcublas
    libcurand
    cuda_nvrtc
  ];
in
rustPlatform.buildRustPackage {
  pname = "deepseek-ocr-rs";
  version = "0-unstable-${sourceInfo.date}";

  src = sourceInfo.src;

  cargoLock = {
    lockFile = sourceInfo.src + "/Cargo.lock";
  };

  stdenv = cudaPackages.backendStdenv;

  nativeBuildInputs = [
    pkg-config
    cmake
    perl
    rustPlatform.bindgenHook
    gitMinimal
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];

  buildInputs = cudaBuildInputs;

  buildFeatures = [ "cuda" ];

  cargoBuildFlags = [
    "-p"
    "deepseek-ocr-cli"
    "-p"
    "deepseek-ocr-server"
    "-p"
    "deepseek-ocr-dsq-cli"
  ];

  cargoInstallFlags = [
    "-p"
    "deepseek-ocr-cli"
    "-p"
    "deepseek-ocr-server"
    "-p"
    "deepseek-ocr-dsq-cli"
  ];

  # cudarc / candle-kernels build scripts read these to locate the toolkit and
  # decide which compute capability to compile for.
  env = {
    CUDA_COMPUTE_CAP = cudaArchitecture;
    CUDA_ROOT = "${cudaRoot}";
    CUDA_PATH = "${cudaRoot}";
    CUDA_TOOLKIT_ROOT_DIR = "${cudaRoot}";
  };

  doCheck = false;

  meta = with lib; {
    description = "Rust rewrite of DeepSeek-OCR with CLI and OpenAI-compatible HTTP server (CUDA build, sm_86)";
    homepage = "https://github.com/TimmyOVO/deepseek-ocr.rs";
    license = licenses.mit;
    mainProgram = "deepseek-ocr-cli";
    platforms = [ "x86_64-linux" ];
  };
}
