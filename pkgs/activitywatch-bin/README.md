# ActivityWatch 使用官方 Apple Silicon 应用包。

`activitywatch-bin` 通过 Nix 安装官方 macOS ARM64 `.dmg` 中的完整
`ActivityWatch.app`。包不依赖 Homebrew 或 Rosetta，不修改应用内的可执行文件。
当前固定版本为 `0.14.0b8`，属于上游预发布版。

## 使用 Nix 构建和启动应用。

在本 NUR 仓库根目录执行：

```sh
nix build .#activitywatch-bin
open ./result/Applications/ActivityWatch.app
open http://127.0.0.1:5600
```

将本仓库的 overlay 加入 nix-darwin 后，可以声明：

```nix
environment.systemPackages = [ pkgs.activitywatch-bin ];
```

nix-darwin 将应用安装到 `/Applications/Nix Apps/ActivityWatch.app`。
在 macOS「系统设置 → 隐私与安全性 → 辅助功能」中为实际安装的应用授予权限，
然后检查 ActivityWatch 网页是否出现窗口记录和窗口标题。

## 独立管理组件时，由用户级 LaunchAgent 启动程序。

包在 `bin/` 下提供以下程序的符号链接：

- `aw-qt` 提供托盘界面，并可启动其他组件。
- `aw-server-rust` 保存事件并提供本机网页。
- `aw-watcher-window` 记录当前窗口。
- `aw-watcher-afk` 记录电脑的使用和空闲状态。

Rust 服务端位于应用内的 `Contents/Frameworks/aw-server-rust`，
其余三个程序位于 `Contents/MacOS/`。

需要进程退出后自动恢复时，在图形登录会话中为服务端和两个采集程序分别配置
LaunchAgent，并设置 `RunAtLoad = true` 和 `KeepAlive = true`。
使用应用安装后的固定路径，避免升级时直接引用变化的 Nix store 路径。
代理环境应为三个进程设置 `NO_PROXY=127.0.0.1,localhost`。

独立管理组件时，不要再通过托盘界面启动相同组件。检查服务端网页之外，
还应检查两个采集程序的事件持续更新，并验证退出进程后能恢复采集。
`KeepAlive` 处理进程退出，不检测仍在运行但停止响应的进程。

记录由 ActivityWatch 保存在用户的
`~/Library/Application Support/activitywatch/`，不写入 Nix store。

## 更新版本后验证权限和采集。

修改 `nvfetcher.toml` 中 `[activitywatch-bin]` 的 `src.manual`，
再使用存放 GitHub 凭据的 keyfile 生成下载校验信息：

```sh
nix develop -c nvfetcher -o _sources -c nvfetcher.toml \
  --keyfile ./keyfile.toml --filter '^activitywatch-bin$'
nix build .#activitywatch-bin
codesign --verify --deep --strict ./result/Applications/ActivityWatch.app
```

生成的 `_sources/generated.nix` 和 `_sources/generated.json` 随包一起提交，
不要手工修改生成文件。keyfile 不应提交到仓库。

更新后验证窗口标题、空闲事件、登录启动和睡眠唤醒后的记录。
如果窗口标题为空，按上游说明从辅助功能列表删除 ActivityWatch，再重新添加；
仅重新勾选权限可能没有效果。

上游说明见 [下载页面](https://activitywatch.net/downloads/)、
[更新文档](https://docs.activitywatch.net/en/latest/updating.html)和
[数据目录文档](https://docs.activitywatch.net/en/latest/directories.html)。
