# wtfps 打包备注

- `pkgs/wtfps/default.nix` 使用 `rustPlatform.buildRustPackage` 构建 Codeberg 上游 `joelkoen/wtfps`。
- 源码通过 `nvfetcher` 统一维护：
  - `[wtfps]`
  - `src.git = "https://codeberg.org/joelkoen/wtfps.git"`
  - `fetch.git = "https://codeberg.org/joelkoen/wtfps.git"`
  - `git.get_commit_date = true`
- 上游没有 tag，包版本使用仓库不稳定包规范：`0-unstable-${generated.wtfps.date}`。
- `cargoLock.lockFile` 指向 `generated.wtfps.src + "/Cargo.lock"`，避免额外维护 vendored lockfile。
- `build.rs` 通过 `prost_build` 调用 `protoc` 编译 `src/apple.proto`，因此 `protobuf` 必须在 `nativeBuildInputs`。
- `reqwest` 的默认 TLS 依赖会链接 OpenSSL，因此 `openssl` 放在 `buildInputs`，`pkg-config` 放在 `nativeBuildInputs`。
- 源码使用 `sqlx::query!` / `query_scalar!` 宏并提交了 `.sqlx/` 离线缓存；构建必须设置 `SQLX_OFFLINE = "true"`，避免 Nix sandbox 内尝试连接真实 PostgreSQL。
- 当前禁用测试（`doCheck = false`），因为上游 CLI 的主要路径依赖 Apple WPS 网络接口或 PostgreSQL 运行时环境。

## 验证

执行过以下命令：

```bash
nix run nixpkgs#nvfetcher -- -o _sources -c ./nvfetcher.toml --keyfile ./keyfile.toml -f '^wtfps$'
nix run nixpkgs#nixfmt -- pkgs/wtfps/default.nix
nix run nixpkgs#statix -- check pkgs/wtfps/default.nix
nix run nixpkgs#deadnix -- pkgs/wtfps/default.nix
nix build .#wtfps -L
nix eval .#packages.x86_64-linux.wtfps.version
nix flake check -L --no-build
```

结果：

- `nix build .#wtfps -L` 构建成功。
- `nix eval .#packages.x86_64-linux.wtfps.version` 输出 `"0-unstable-2024-10-21"`。
- `statix` / `deadnix` 对 `pkgs/wtfps/default.nix` 无输出。
- `nix flake check -L --no-build` 中 `packages.x86_64-linux.wtfps` eval 成功；仓库既有输出 `kernel-rss-opt-patches`、`rime-custom-pinyin-dictionary`、`dbhub`、`cloudflarespeedtest` 失败，非本包改动引入。
