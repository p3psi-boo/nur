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
  - 使用 `nix develop . -c $SHELL`，或 `nix run nixpkgs#nvfetcher -- -o _sources -c ./nvfetcher.toml --keyfile ./keyfile.toml`
- 重要：必须使用 `--keyfile ./keyfile.toml` 参数，否则会因 GitHub API 速率限制导致 403 错误
- 禁止直接修改 `_sources/` 下的文件（`generated.{nix,json}`），这些文件均由 `nvfetcher` 从 `./nvfetcher.toml` 自动生成。如需更新或删除包，请修改 `./nvfetcher.toml` 后重新运行 `nvfetcher` 命令

参考：`https://github.com/berberman/nvfetcher`
