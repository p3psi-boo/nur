# agsh 打包备注

- `pkgs/agsh/default.nix` 使用 `rustPlatform.buildRustPackage` 构建 GitHub 上游 `k4yt3x/agsh`。
- 源码通过 `nvfetcher` 统一维护：
  - `[agsh]`
  - `src.github = "k4yt3x/agsh"`
  - `fetch.github = "k4yt3x/agsh"`
- 包版本直接使用 `generated.agsh.version`，源码直接使用 `generated.agsh.src`。
- `cargoLock.lockFile` 指向 `${finalAttrs.src}/Cargo.lock`。
- 上游锁文件中的 `reedline-0.45.0` 是 git dependency：`https://github.com/wtfbbqhax/reedline?rev=3a457ff1dab28c9021db116f2575eed5116bed88`，必须在 `cargoLock.outputHashes` 固定为 `sha256-ta4XbKOjb2qDmfmAHbNPARqkpm2jPS4L+oglefoirLY=`，否则 vendoring 会因缺少 git dependency hash 失败。
- 构建依赖：`pkg-config` 与 `rustPlatform.bindgenHook` 放在 `nativeBuildInputs`；`openssl` 与 `sqlite` 放在 `buildInputs`。
- 当前禁用测试（`doCheck = false`）。

## 验证

执行过以下命令：

```bash
nix run nixpkgs#nixfmt -- pkgs/agsh/default.nix
nix run nixpkgs#statix -- check pkgs/agsh/default.nix
nix run nixpkgs#deadnix -- pkgs/agsh/default.nix
nix build .#agsh -L
nix eval .#packages.x86_64-linux.agsh.version
```

结果：

- `nix build .#agsh -L` 构建成功。
- `nix eval .#packages.x86_64-linux.agsh.version` 输出 `"0.18.4"`。
- `statix` / `deadnix` 对 `pkgs/agsh/default.nix` 无输出。
