# NUR package repo

这个目录现在是一个可单独发布/单独消费的包仓库。

## 结构

- `flake.nix`: 独立 flake 入口
- `flake.lock`: 独立锁文件
- `default.nix`: 传统 NUR / 非 flake 入口
- `repo.nix`: 标准包属性集定义
- `overlay.nix`: overlay 入口
- `ci.nix`: CI / checks 入口
- `pkgs/`: 自定义包定义
- `_sources/`: `nvfetcher` 生成的源码信息
- `nvfetcher.toml`: 上游版本声明
- `mods/`: 包构建辅助逻辑

## 独立使用（在 `nur/` 仓库根目录）

```bash
nix flake show
nix build .#lazyssh
nix develop
nvfetcher -o _sources -c nvfetcher.toml --keyfile ../keyfile.toml
```

## 作为上级配置仓子目录使用

```bash
nix flake show ./nur
nix build ./nur#lazyssh
nix develop ./nur
nvfetcher -o nur/_sources -c nur/nvfetcher.toml --keyfile ./keyfile.toml
```

## 非 flake 入口

```bash
nix-build -A lazyssh
nix-build ci.nix -A lazyssh
```
