# coe: 修复 CGO 构建缺失 pkg-config

## 背景
在 `pkgs/coe/default.nix` 的 `coeMain`（`buildGoModule`）构建阶段，报错：

- `gopkg.in/hraban/opus.v2: exec: "pkg-config": executable file not found in $PATH`

该错误出现在 opus 的 CGO 依赖探测阶段。

## 根因
`coeMain` 仅设置了：

- `buildInputs = [ libopus opusfile libogg ]`
- `PKG_CONFIG_PATH` 环境变量

但未把 `pkg-config` 本体加入 `nativeBuildInputs`，导致构建时 PATH 不含 `pkg-config` 可执行文件。

## 修复
在 `coeMain = buildGoModule { ... }` 中新增：

```nix
nativeBuildInputs = [
  pkg-config
];
```

## 验证
执行：

```bash
cd /home/bubu/nur
nix build .#coe -L
```

结果：`coeMain` 与最终组合包均构建通过，原始 `pkg-config` 缺失错误消失。
