# vllm - High-throughput and memory-efficient inference and serving engine for LLMs
# https://github.com/vllm-project/vllm
{
  lib,
  uv-builder,
  cudatoolkit,
  clang,
  generated,
  isWSL ? false,
}:

let
  inherit (generated.vllm) version;

  # LD_LIBRARY_PATH configuration
  ldPath = if isWSL then "/usr/lib/wsl/lib" else "/run/opengl-driver/lib";
in

uv-builder.buildUvPackage {
  pname = "vllm";
  inherit version;

  # Lock file from refs/nix
  lockUrl = "https://static.g7c.us/lock/uv/vllm/0.15.0.lock";
  lockHash = "sha256-BztrLaLBZ2Fqc42+qe/Inyq0qcaFAMHAODQMU8yfLw8=";

  bins = [ "vllm" ];

  # Extra dependencies required by vllm
  extraDependencies = [
    "flashinfer-python==0.5.3"
    "qwen-vl-utils==0.0.14"
  ];

  # Enable CUDA support
  cudaSupport = true;

  # Exclude "vllm" wheel to avoid collision with "v" source package (both provide vllm metadata)
  # The "v" package is the source build that provides console scripts
  excludePackages = [ "vllm" ];

  # Post-install: wrap binary with CUDA environment
  postInstall = ''
    wrapProgram $out/bin/vllm \
      --set LD_LIBRARY_PATH "${ldPath}" \
      --set TRITON_LIBCUDA_PATH "${ldPath}" \
      --set TRITON_PTXAS_PATH "${cudatoolkit}/bin/ptxas" \
      --prefix PATH : ${clang}/bin
  '';

  passthru = {
    # WSL variant with adjusted library paths
    wsl = uv-builder.buildUvPackage {
      pname = "vllm";
      inherit version;
      lockUrl = "https://static.g7c.us/lock/uv/vllm/${version}.lock";
      lockHash = "sha256-BztrLaLBZ2Fqc42+qe/Inyq0qcaFAMHAODQMU8yfLw8=";
      bins = [ "vllm" ];
      extraDependencies = [
        "flashinfer-python==0.5.3"
        "qwen-vl-utils==0.0.14"
      ];
      cudaSupport = true;
      isWSL = true;
    };
  };

  meta = {
    changelog = "https://github.com/vllm-project/vllm/releases/tag/v${version}";
    description = "High-throughput and memory-efficient inference and serving engine for LLMs";
    homepage = "https://github.com/vllm-project/vllm";
    license = lib.licenses.asl20;
    mainProgram = "vllm";
    platforms = lib.platforms.linux;
    skipBuild = true; # Heavy build - skip in CI
  };
}
