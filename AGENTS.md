# Agent 指南（本仓库）

## Nix 打包小工具

- 打包前先用 `nh search <query>` 在 nixpkgs 里查一下是否已有相关包；如果已有（满足需求），不要在本仓库继续打包/新增。
- 在写/更新 Nix 包（需要 `fetchFromGitHub`、`fetchgit`、`fetchurl` 等）时，优先用 `nurl` 快速生成/获取 `owner/repo`、`rev`、`hash` 等信息：`https://github.com/nix-community/nurl`。

## nvfetcher（统一维护源码版本）

用 `nvfetcher` 统一维护 `pkgs/` 下包的上游版本与源码信息（配置：`./nvfetcher.toml`，输出：`_sources/generated.{nix,json}`）。

- 更新方式：
  - 修改 `./nvfetcher.toml`
  - 运行 `nvfetcher -o _sources -c ./nvfetcher.toml --keyfile ./keyfile.toml`
  - 提交更新后的 `_sources/generated.{nix,json}`
- 使用方式：
  - 包的 `default.nix` 引用 `generated.<pkg>.src`、`generated.<pkg>.version` 等字段
  - NUR overlay 会自动把 `generated` 传给同名包（目录名与 `nvfetcher.toml` 的段名一致即可）
- 获取命令：
  - 使用 `nix develop ./nur -c $SHELL`，或 `nix run nixpkgs#nvfetcher -- -o _sources -c ./nvfetcher.toml --keyfile ./keyfile.toml`
- 重要：必须使用 `--keyfile ./keyfile.toml` 参数，否则会因 GitHub API 速率限制导致 403 错误
- 禁止直接修改 `_sources/` 下的文件（`generated.{nix,json}`），这些文件均由 `nvfetcher` 从 `./nvfetcher.toml` 自动生成。如需更新或删除包，请修改 `./nvfetcher.toml` 后重新运行 `nvfetcher` 命令

参考：`https://github.com/berberman/nvfetcher`

## uv2nix（Python 项目打包）

本仓库使用 [uv2nix](https://github.com/pyproject-nix/uv2nix) 将基于 `uv.lock` 的 Python 项目打包为 Nix 包。核心封装在 `mods/python/uv-builder.nix`，通过 `python-uv.nix` overlay 暴露为 `pkgs.uv-builder`。

- 使用方式：
  - 在包的 `default.nix` 中引入 `uv-builder`，调用 `uv-builder.buildUvPackage { ... }` 构建 Python 环境
  - 必需参数：`pname`、`version`、`lockFile`（本地路径）或 `lockUrl` + `lockHash`（远程 URL）
  - 常用可选参数：
    - `bins`：要暴露的可执行文件列表（默认 `[ pname ]`）
    - `python`：Python 解释器（默认 `python313`）
    - `extraDependencies`：额外 pip 依赖
    - `cudaSupport`：启用 CUDA 支持（自动处理 torch/vllm 等常见包的 autoPatchelf）
    - `pyprojectOverrides`：自定义 pyproject overlay（用于修补特定 Python 包）
    - `excludePackages`：排除冲突包
- 示例（参考 `pkgs/grok2api/default.nix`）：
  ```nix
  pythonEnv = uv-builder.buildUvPackage {
    pname = "my-app";
    version = "1.0.0";
    lockFile = "${src}/uv.lock";
    bins = [ "python" "my-app" ];
  };
  ```
- 工作原理：`buildUvPackage` 会根据 `uv.lock` 生成临时 workspace，通过 `uv2nix.lib.workspace.loadWorkspace` 解析依赖，使用 `pyproject-nix` 构建 Python 包集合，最终组装为虚拟环境

参考：`https://github.com/pyproject-nix/uv2nix`

## copilot-api-plus 打包备注

- `pkgs/copilot-api-plus` 使用 npm 发布 tarball 作为 `src`（包含 `dist/` 产物），版本号仍使用 nvfetcher 的 `generated.copilot-api-plus.date` 组装 `0-unstable-YYYY-MM-DD`。
- 上游 lockfile 在本仓库环境下会触发离线缓存缺失，因此该包固定使用仓库内 vendored 的生产依赖 lockfile：`pkgs/copilot-api-plus/package-lock.json`。
- `default.nix` 在 `postPatch` 中同步裁剪 `package.json` 到运行时字段（name/version/type/bin/dependencies），确保与 vendored lockfile 一致，避免 `npm ci` 拉取 devDependencies。

## gemma-cpp CUDA 构建备注

- `pkgs/gemma-cpp/default.nix` 固定为 **CUDA-only** 构建，且目标架构固定为 **RTX 30 系列 / Ampere (`sm_86`)**。
- 关键开关：
  - `GGML_CUDA = true`
  - `CMAKE_CUDA_ARCHITECTURES = "86"`
- 该包当前**没有**对外暴露可覆盖的 CUDA 架构参数；不要在说明中暗示可通过 `overrideAttrs` 直接覆盖，除非先把该参数显式提升到 derivation 接口。

## lucebox-hub 打包备注

- `pkgs/lucebox-hub/default.nix` 当前只打包 **`dflash/` 运行时**，不打包 `megakernel/`；原因是上游仓库根只是聚合入口，而 `megakernel/` 缺少锁文件与稳定的 Python 打包元数据。
- `dflash` 依赖固定的 `dflash/deps/llama.cpp` 子模块，但当前 `nvfetcher` 生成的 `generated.lucebox-hub.src` 未带出子模块内容；包内通过额外 `fetchFromGitHub` 把 **`Luce-Org/llama.cpp@b16de65904ed7e468397f5417ad130f092cba8f4`** 注入到期望路径。
- 运行时模型权重始终保持外置，不进入 Nix closure。使用以下环境变量指向本地权重：
  - `DFLASH_TARGET=/path/to/Qwen3.5-27B-Q4_K_M.gguf`
  - `DFLASH_DRAFT=/path/to/model.safetensors` 或其 snapshot 目录
- 上游脚本的运行时路径覆盖统一保存在 `pkgs/lucebox-hub/patches/0001-dflash-runtime-env-overrides.patch`，不要再回退到 `postPatch` 里的脚本式文本替换。
- `lucebox-hub` 的 Python wrapper 环境必须避免把 Hugging Face 依赖链里的 **test-only** `safetensors -> torch -> triton` 带进来；当前做法是在包内局部 override `safetensors` 为 `doCheck = false` 且清空 `nativeCheckInputs`，只收缩本包运行时闭包，不修改仓库全局 Python 策略。
- `lucebox-hub` 的 `run.py` / `server.py` 都会调用 `tokenizer.apply_chat_template(...)`，运行时必须包含 `jinja2`（及其传递依赖 `markupsafe`）。若缺失会触发 `ImportError: apply_chat_template requires jinja2` 并导致 `lucebox-hub-server` 返回 500。
- `lucebox-hub` 的 Python 解释器应显式固定为 `python313`，避免依赖 nixpkgs `python3` 别名在未来漂移导致运行时行为变化。
- CUDA 架构固定为 **Ampere / `sm_86`**，与上游构建说明及仓库内现有 CUDA 包策略保持一致。

## komari 运行时版本号注入备注

- `pkgs/komari/default.nix` 必须通过 Go `ldflags` 注入：
  - `github.com/komari-monitor/komari/utils.CurrentVersion`
  - `github.com/komari-monitor/komari/utils.VersionHash`
- 原因：上游 `utils/version.go` 默认值是 `0.0.1` / `unknown`，若不注入，`/api/version` 和启动日志会显示错误运行时版本。
- 注入值应与 Nix 包版本保持一致：`CurrentVersion = 0-unstable-${generated.komari.date}`，`VersionHash = generated.komari.version`。

## trusttunnel 打包备注

- `pkgs/trusttunnel/default.nix` 通过 `rustPlatform.buildRustPackage` 同时构建 workspace 里的 `trusttunnel_endpoint` 与 `setup_wizard` 两个二进制。
- `trusttunnel` 使用 `nvfetcher` 的 GitHub release 跟踪：
  - `[trusttunnel]`
  - `src.github = "TrustTunnel/TrustTunnel"`
  - `fetch.github = "TrustTunnel/TrustTunnel"`
- 版本号在包内统一做 `lib.removePrefix "v"`，避免把 tag 前缀带入最终包版本字符串。
- 上游依赖 `boring-sys` / `quiche`，构建时需要调用 `git` 给 boringssl 源码打补丁；缺失 `git` 会导致 build script 失败。
- 因此 `nativeBuildInputs` 需要显式包含 `gitMinimal`（以及 `cmake/go/perl/nasm/pkg-config/rustPlatform.bindgenHook`）。

## open-coreui 打包备注

- `pkgs/open-coreui/default.nix` 当前仅打包 Go 服务端（`backend/cmd/openwebui`），不打包 Python 后端。
- 上游 Go module 位于 `backend/`，必须显式设置 `modRoot = "backend"` 与 `subPackages = [ "cmd/openwebui" ]`。
- 运行时需要 `open-webui` 子模块里的静态资源；`nvfetcher.toml` 的 `[open-coreui]` 必须保持 `git.fetchSubmodules = true`。
- 包内会把 `open-webui/backend/open_webui/static` 复制到 `$out/share/open-coreui/static`，并通过 wrapper 默认注入 `STATIC_DIR`，避免 `/static/favicon.png` 等资源 404。
- 服务端默认反向代理到 `OPEN_COREUI_PYTHON_BASE_URL`（默认 `http://127.0.0.1:8080`）；部署时需自行提供该上游服务。

---

打包请查看 `nix-package` SKILL

