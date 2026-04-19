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

## komari 运行时版本号注入备注

- `pkgs/komari/default.nix` 必须通过 Go `ldflags` 注入：
  - `github.com/komari-monitor/komari/utils.CurrentVersion`
  - `github.com/komari-monitor/komari/utils.VersionHash`
- 原因：上游 `utils/version.go` 默认值是 `0.0.1` / `unknown`，若不注入，`/api/version` 和启动日志会显示错误运行时版本。
- 注入值应与 Nix 包版本保持一致：`CurrentVersion = 0-unstable-${generated.komari.date}`，`VersionHash = generated.komari.version`。

---

打包请查看 `nix-package` SKILL

