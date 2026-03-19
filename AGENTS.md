# Agent 指南（本仓库）

## Nix 打包小工具

- 自定义包仓库已拆分到 `nur/`；涉及打包/更新包时，优先在 `nur/` 下操作。
- 打包前先用 `nh search <query>` 在 nixpkgs 里查一下是否已有相关包；如果已有（满足需求），不要在本仓库继续打包/新增。
- 在写/更新 Nix 包（需要 `fetchFromGitHub`、`fetchgit`、`fetchurl` 等）时，优先用 `nurl` 快速生成/获取 `owner/repo`、`rev`、`hash` 等信息：`https://github.com/nix-community/nurl`。
- 包相关工具请优先使用 `nix develop ./nur` 进入 NUR 的 devShell。

## nvfetcher（统一维护源码版本）

用 `nvfetcher` 统一维护 `nur/pkgs/` 下包的上游版本与源码信息（配置：`nur/nvfetcher.toml`，输出：`nur/_sources/generated.{nix,json}`）。

- 更新方式：
  - 修改 `nur/nvfetcher.toml`
  - 运行 `nvfetcher -o nur/_sources -c nur/nvfetcher.toml --keyfile ./keyfile.toml`
  - 提交更新后的 `nur/_sources/generated.{nix,json}`
- 使用方式：
  - 包的 `default.nix` 引用 `generated.<pkg>.src`、`generated.<pkg>.version` 等字段
  - NUR overlay 会自动把 `generated` 传给同名包（目录名与 `nur/nvfetcher.toml` 的段名一致即可）
- 获取命令：
  - 使用 `nix develop ./nur -c $SHELL`，或 `nix run nixpkgs#nvfetcher -- -o nur/_sources -c nur/nvfetcher.toml --keyfile ./keyfile.toml`
- 重要：必须使用 `--keyfile ./keyfile.toml` 参数，否则会因 GitHub API 速率限制导致 403 错误
- 禁止直接修改 `nur/_sources/` 下的文件（`generated.{nix,json}`），这些文件均由 `nvfetcher` 从 `nur/nvfetcher.toml` 自动生成。如需更新或删除包，请修改 `nur/nvfetcher.toml` 后重新运行 `nvfetcher` 命令

参考：`https://github.com/berberman/nvfetcher`

## Rust 打包

- Rust 打包时需要注意二进制大小优化、编译选项等问题，详见 [Rust 二进制大小优化文档](docs/min-sized-rust.md)（来源：[min-sized-rust](https://github.com/johnthagen/min-sized-rust)）
