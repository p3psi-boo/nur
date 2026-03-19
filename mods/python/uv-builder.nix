# UV-based Python package builder
# Complete implementation based on refs/nix/mods/py_madness.nix
#
# Core dependencies: uv2nix, pyproject-nix, pyproject-build-systems
{
  pkgs,
  lib,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}:

let
  inherit (pkgs)
    stdenv
    fetchurl
    rsync
    makeWrapper
    runCommand
    ;
  inherit (lib) optionalAttrs optionalString concatMapStringsSep;
in

rec {
  # Build a Python package from uv.lock
  buildUvPackage =
    {
      pname,
      version,
      python ? pkgs.python313,
      bins ? [ pname ],
      lockFile ? null,
      lockUrl ? null,
      lockHash ? null,
      extraDependencies ? [ ],
      cudaSupport ? false,
      pyprojectOverrides ? (_: _: { }),
      includePin ? true,
      includeSelf ? true,
      # Packages to exclude from the virtual environment (for collision handling)
      excludePackages ? [ ],
      ...
    }@args:

    let
      # Fetch lock file from URL if provided
      lockFileContent =
        if lockUrl != null then
          fetchurl {
            url = lockUrl;
            hash = lockHash;
          }
        else if lockFile != null then
          lockFile
        else
          throw "Either lockFile or lockUrl must be provided";

      # Build dependency list for pyproject.toml
      dependencies = (if includePin then [ "${pname}==${version}" ] else [ ]) ++ extraDependencies;

      # Create temporary workspace root with pyproject.toml and uv.lock
      workspaceRoot = runCommand "${pname}-workspace" { } ''
              mkdir -p $out
              
              # Create minimal pyproject.toml
              cat > $out/pyproject.toml <<EOF
        [project]
        name = "${pname}"
        version = "${version}"
        dependencies = [
        ${concatMapStringsSep "\n" (dep: "  \"${dep}\",") dependencies}
        ]
        EOF
              
              # Copy lock file
              cp ${lockFileContent} $out/uv.lock
      '';

      # Load workspace using uv2nix
      workspace = uv2nix.lib.workspace.loadWorkspace {
        inherit workspaceRoot;
      };

      # Create pyproject overlay
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel"; # Prefer wheels over source
      };

      # Default overlay for common package fixes
      defaultOverlay =
        final: prev:
        {
          # numba requires libtbb.so.12 for tbbpool module
          numba = prev.numba.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [ "libtbb.so.12" ];
            buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.tbb_2022 ];
          });
          # nvidia-cufile-cu12 has optional RDMA support requiring InfiniBand libs
          nvidia-cufile-cu12 = prev.nvidia-cufile-cu12.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libmlx5.so.1"
              "librdmacm.so.1"
              "libibverbs.so.1"
            ];
          });
          # nvidia-cutlass-dsl needs libcuda.so.1 which is provided by NVIDIA driver at runtime
          nvidia-cutlass-dsl = prev.nvidia-cutlass-dsl.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [ "libcuda.so.1" ];
          });
          # nvidia-nvshmem-cu12 has optional HPC/cluster communication libs
          nvidia-nvshmem-cu12 = prev.nvidia-nvshmem-cu12.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libmpi.so.40"
              "libpmix.so.2"
              "liboshmem.so.40"
              "libmlx5.so.1"
              "libucs.so.0"
              "libucp.so.0"
              "libfabric.so.1"
              "libcuda.so.1"
            ];
          });
        }
        // lib.optionalAttrs cudaSupport {
          # cupy-cuda12x needs CUDA runtime libraries
          cupy-cuda12x = prev.cupy-cuda12x.overrideAttrs (old: {
            buildInputs =
              (old.buildInputs or [ ])
              ++ (with pkgs.cudaPackages; [
                libcusolver
                libcublas
                cudnn
                libcurand
                libcusparse
                libcutensor
                nccl
                cuda_nvrtc
                libcufft
              ]);
            # libcuda.so.1 is provided by NVIDIA driver at runtime
            # libcudnn.so.8 - cupy expects cudnn8 but we have cudnn9
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libcuda.so.1"
              "libcudnn.so.8"
            ];
          });
          # nvidia-cusolver-cu12 needs other nvidia-* Python packages for linking (available at runtime)
          nvidia-cusolver-cu12 = prev.nvidia-cusolver-cu12.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libnvJitLink.so.12"
              "libcublas.so.12"
              "libcublasLt.so.12"
              "libcusparse.so.12"
            ];
          });
          # nvidia-cusparse-cu12 needs nvjitlink (available at runtime)
          nvidia-cusparse-cu12 = prev.nvidia-cusparse-cu12.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libnvJitLink.so.12"
            ];
          });
          # torch needs many CUDA libraries (available at runtime via LD_LIBRARY_PATH)
          torch = prev.torch.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libcuda.so.1"
              "libcupti.so.12"
              "libcudart.so.12"
              "libcusparse.so.12"
              "libcufft.so.11"
              "libcufile.so.0"
              "libcusparseLt.so.0"
              "libnccl.so.2"
              "libcurand.so.10"
              "libcublas.so.12"
              "libcublasLt.so.12"
              "libcudnn.so.9"
              "libnvshmem_host.so.3"
              "libcusolver.so.11"
              "libnvrtc.so.12"
            ];
          });
          # torchaudio needs torch libraries (available at runtime)
          torchaudio = prev.torchaudio.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libtorch.so"
              "libtorch_cpu.so"
              "libtorch_cuda.so"
              "libc10.so"
              "libc10_cuda.so"
              "libtorch_python.so"
              "libcudart.so.12"
            ];
          });
          # torchvision needs torch libraries (available at runtime)
          torchvision = prev.torchvision.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libtorch.so"
              "libtorch_cpu.so"
              "libtorch_cuda.so"
              "libc10.so"
              "libc10_cuda.so"
              "libtorch_python.so"
              "libcudart.so.12"
            ];
          });
          # vllm needs torch and CUDA libraries (available at runtime)
          vllm = prev.vllm.overrideAttrs (old: {
            autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
              "libtorch.so"
              "libtorch_cpu.so"
              "libtorch_cuda.so"
              "libc10.so"
              "libc10_cuda.so"
              "libcudart.so.12"
              "libcuda.so.1"
            ];
          });
        };

      # Create Python environment with overlays
      pythonSet =
        (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope
          (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              overlay
              defaultOverlay
              pyprojectOverrides
            ]
          );

      # Build UV environment
      uvEnv = (pythonSet.mkVirtualEnv "${pname}-env" workspace.deps.default).overrideAttrs {
        # Skip broken symlink check
        dontCheckForBrokenSymlinks = true;
      };
    in

    stdenv.mkDerivation {
      inherit pname version;

      dontUnpack = true;
      # Skip broken symlink check (vllm workspace has reflexive env-vars symlink)
      dontCheckForBrokenSymlinks = true;

      nativeBuildInputs = [
        rsync
        makeWrapper
      ];

      installPhase = ''
        mkdir -p $out

        # Copy UV environment (exclude bin/), make writable
        ${rsync}/bin/rsync -a --chmod=u+w --exclude='bin/' ${uvEnv}/ $out/

        # Copy specific binaries
        mkdir -p $out/bin
        ${concatMapStringsSep "\n" (bin: ''
          if [ -f ${uvEnv}/bin/${bin} ]; then
            cp ${uvEnv}/bin/${bin} $out/bin/${bin}
          fi
        '') bins}
      '';

      passthru = args.passthru or { };

      meta = args.meta or { };
    };
}
