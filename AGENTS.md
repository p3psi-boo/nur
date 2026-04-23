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

## codex-desktop-linux 打包备注

- `pkgs/codex-desktop-linux` 采用 **runtime installer wrapper** 模式：Nix 包仅分发上游安装脚本与固定哈希的 `Codex.dmg`，实际 `codex-app/` 由用户在运行时目录生成。
- 这样处理是为了避免把 Electron 重建产物写入 Nix store（上游安装流程要求可写工作目录，并会执行 `npm/npx` 的本地重建步骤）。
- 运行入口 `codex-desktop-linux` 会在临时目录复制上游源码并执行 `install.sh`，然后对生成的 Electron 二进制做 `patchelf`（`interpreter + rpath`）以适配 NixOS 动态链接行为。
- 上游生成的 `start.sh` 默认 shebang 为 `/bin/bash`；wrapper 会在安装完成后重写为 Nix store 内 `bash` 路径，避免 NixOS 上 `bad interpreter: /bin/bash`。
- 包输出额外提供桌面集成：`$out/share/applications/codex-desktop-linux.desktop` 与图标 `$out/share/icons/hicolor/256x256/apps/codex-desktop-linux.png`；桌面入口调用 `codex-desktop-linux-launcher`（已安装时直启，未安装时触发首次安装）。
- `Codex.dmg` 是固定输出依赖；若上游在同 URL 发布新版本导致 hash mismatch，需要同步更新 `pkgs/codex-desktop-linux/default.nix` 内 `codexDmg.hash`。
- 版本号遵循仓库现有不稳定包规范：`0-unstable-${generated.codex-desktop-linux.date}`。

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

---

打包请查看 `nix-package` SKILL

