{
  lib,
  autoAddDriverRunpath,
  cmake,
  cudaPackages,
  ninja,
  patchelf,
  generated,
}:

let
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

  runtimeLibraryPath = lib.makeLibraryPath (cudaBuildInputs ++ [
    effectiveStdenv.cc.cc.lib
  ]);
in

effectiveStdenv.mkDerivation (finalAttrs: {
  pname = "vibevoice-cpp";
  version = "0-unstable-${generated.vibevoice-cpp.date}";

  src = generated.vibevoice-cpp.src;

  nativeBuildInputs = [
    autoAddDriverRunpath
    cmake
    cudaPackages.cuda_nvcc
    ninja
    patchelf
  ];

  buildInputs = cudaBuildInputs;

  cmakeFlags = [
    (cmakeBool "VIBEVOICE_BUILD_EXAMPLES" true)
    (cmakeBool "VIBEVOICE_BUILD_TESTS" finalAttrs.finalPackage.doCheck)
    (cmakeBool "VIBEVOICE_BUILD_SERVER" false)
    (cmakeBool "VIBEVOICE_GGML_CUDA" true)
    (cmakeBool "VIBEVOICE_SHARED" false)
    (cmakeBool "GGML_NATIVE" false)
    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaArchitectures)
  ];

  postInstall = ''
    mkdir -p $out/lib
    cp -P third_party/ggml/src/libggml*.so* $out/lib/
    cp -P third_party/ggml/src/ggml-cuda/libggml-cuda.so* $out/lib/

    install -Dm755 bin/vibevoice-cli $out/bin/vibevoice-cli
    install -Dm755 bin/vibevoice-quantize $out/bin/vibevoice-quantize

    find $out/lib -type f -name 'libggml*.so*' -exec patchelf --set-rpath $out/lib:${runtimeLibraryPath} {} \;
    patchelf --set-rpath $out/lib:${runtimeLibraryPath} $out/bin/vibevoice-cli
    patchelf --set-rpath $out/lib:${runtimeLibraryPath} $out/bin/vibevoice-quantize
  '';

  doCheck = false;

  meta = {
    description = "C++ inference engine for Microsoft VibeVoice TTS and ASR";
    homepage = "https://github.com/mudler/vibevoice.cpp";
    license = lib.licenses.mit;
    mainProgram = "vibevoice-cli";
    platforms = lib.platforms.linux;
    badPlatforms = lib.platforms.darwin;
  };
})
