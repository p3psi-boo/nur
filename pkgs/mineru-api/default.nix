# mineru-api - MinerU FastAPI server (Linux + CUDA / vllm backend)
# https://github.com/opendatalab/MinerU
#
# 方案 A: uv2nix + 仓库内 vendored uv.lock。上游没有 uv.lock，因此本目录的
# uv.lock 是用 `uv lock` 针对 `mineru[core,vllm]==<version>` 在本仓库生成
# 的工件，跟随上游版本一起更新。模型权重不进 Nix store，运行时通过
# `MINERU_MODEL_SOURCE=local` 与 huggingface/modelscope 缓存目录注入。
{
  lib,
  stdenv,
  uv-builder,
  makeWrapper,
  addDriverRunpath,
  generated,
}:

let
  sourceInfo = generated.mineru-api;

  # 上游 git tag 形如 `mineru-3.1.6-released`，提取裸版本号用于 PyPI 解析。
  upstreamVersion =
    let
      stripped = lib.removePrefix "mineru-" sourceInfo.version;
    in
    lib.removeSuffix "-released" stripped;

  # Nix 包版本直接采用上游 PyPI 版本号。
  version = upstreamVersion;

  # uv-builder 内部使用，必须与 vendored uv.lock 中的 [project] 段保持一致。
  envVersion = "0.0.0";

  pythonEnv = uv-builder.buildUvPackage {
    pname = "mineru-api";
    version = envVersion;
    lockFile = ./uv.lock;
    includePin = false;
    extraDependencies = [
      "mineru[core,vllm]==${upstreamVersion}"
    ];
    cudaSupport = true;
    # 这两个包仅有 sdist 且未在自身 pyproject.toml 中声明 setuptools 为构建依赖，
    # uv2nix 在隔离环境下构建会因找不到 setuptools 报错。手动补齐。
    pyprojectOverrides = final: prev: {
      antlr4-python3-runtime = prev.antlr4-python3-runtime.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ final.resolveBuildSystem { setuptools = [ ]; };
      });
      pylatexenc = prev.pylatexenc.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ final.resolveBuildSystem { setuptools = [ ]; };
      });
      # 解决 opencv-python（mineru 直接依赖）与 opencv-python-headless
      # （albumentations / albucore 依赖）的 cv2/cv2.abi3.so 文件冲突。
      # 这里把 headless 直接别名到 opencv-python，让 mkVirtualEnv 视作同一
      # 输出而去重——避免在 server 场景额外引入 GUI 版 opencv。
      opencv-python-headless = prev.opencv-python;

      # xformers ships pre-built CUDA extensions linked against torch / CUDA
      # runtime libraries that are loaded transitively at import time.
      # 与 torch/torchvision/vllm 同处理：构建期忽略，运行期通过
      # LD_LIBRARY_PATH（驱动） + 同 venv 内的 torch（提供 libtorch.so 等）解析。
      xformers = prev.xformers.overrideAttrs (old: {
        autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ [
          "libtorch.so"
          "libtorch_cpu.so"
          "libtorch_cuda.so"
          "libc10.so"
          "libc10_cuda.so"
          "libtorch_python.so"
          "libcudart.so.12"
          "libcuda.so.1"
        ];
      });
    };
    bins = [
      "mineru"
      "mineru-api"
      "mineru-router"
      "mineru-openai-server"
      "mineru-gradio"
      "mineru-models-download"
      "python"
      "python3"
    ];
    meta = {
      description = "MinerU runtime virtualenv (CUDA / vllm backend)";
    };
  };
in

stdenv.mkDerivation {
  pname = "mineru-api";
  inherit version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # 暴露 mineru 全家桶 CLI 与 python 解释器，统一注入运行时环境。
    for bin in mineru mineru-router mineru-openai-server mineru-gradio mineru-models-download python python3; do
      if [ -f ${pythonEnv}/bin/$bin ]; then
        makeWrapper ${pythonEnv}/bin/$bin $out/bin/$bin \
          --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib" \
          --set-default TORCH_CUDNN_V8_API_DISABLED 1
      fi
    done

    # mineru-api 入口：默认监听 0.0.0.0:8000，便于容器/服务化部署。
    # 用户可通过环境变量覆盖各项默认值，或追加自定义 CLI 参数。
    cat > $out/bin/mineru-api <<EOF
    #!${stdenv.shell}
    set -e

    # ===== Server =====
    : "\''${MINERU_API_HOST:=0.0.0.0}"
    : "\''${MINERU_API_PORT:=8000}"

    # ===== Model source =====
    # huggingface | modelscope | local
    : "\''${MINERU_MODEL_SOURCE:=huggingface}"
    export MINERU_MODEL_SOURCE

    # ===== Output / cache directories (运行时数据，禁止落到 Nix store) =====
    : "\''${MINERU_API_OUTPUT_ROOT:=\$PWD/output}"
    export MINERU_API_OUTPUT_ROOT
    mkdir -p "\$MINERU_API_OUTPUT_ROOT"

    # ===== Concurrency / docs / retention =====
    : "\''${MINERU_API_MAX_CONCURRENT_REQUESTS:=3}"
    export MINERU_API_MAX_CONCURRENT_REQUESTS
    : "\''${MINERU_API_ENABLE_FASTAPI_DOCS:=true}"
    export MINERU_API_ENABLE_FASTAPI_DOCS
    : "\''${MINERU_API_TASK_RETENTION_SECONDS:=86400}"
    export MINERU_API_TASK_RETENTION_SECONDS

    # ===== Torch / CUDA =====
    export TORCH_CUDNN_V8_API_DISABLED=1
    export LD_LIBRARY_PATH="${addDriverRunpath.driverLink}/lib\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"

    exec ${pythonEnv}/bin/mineru-api \
      --host "\$MINERU_API_HOST" \
      --port "\$MINERU_API_PORT" \
      "\$@"
    EOF
    chmod +x $out/bin/mineru-api

    runHook postInstall
  '';

  passthru = {
    inherit pythonEnv;
    upstreamVersion = upstreamVersion;
  };

  meta = {
    description = "MinerU FastAPI document parsing server (CUDA / vllm backend)";
    homepage = "https://github.com/opendatalab/MinerU";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "mineru-api";
  };
}
