# open-coreui 服务端打包备注

- `pkgs/open-coreui/default.nix` 使用 `buildGoModule` 打包 Go 服务端，仅构建：
  - `backend/cmd/openwebui`
- 上游 Go module 位于子目录，需固定：
  - `modRoot = "backend"`
  - `subPackages = [ "cmd/openwebui" ]`
- 上游仓库通过 git submodule 引入 `open-webui` 前端静态资源；为保证运行时 `/static/*` 路径可用，`nvfetcher.toml` 的 `[open-coreui]` 必须启用：
  - `git.fetchSubmodules = true`
- `postInstall` 将 submodule 中静态资源复制到：
  - `$out/share/open-coreui/static`
  并通过 wrapper 为 `open-coreui` 默认注入：
  - `STATIC_DIR=$out/share/open-coreui/static`
- 该服务端默认反向代理到独立 Python 后端（默认 `OPEN_COREUI_PYTHON_BASE_URL=http://127.0.0.1:8080`）；本包仅提供 Go 服务端，不打包 Python 后端。
- 当前构建配置为纯静态倾向（`CGO_ENABLED=0`）并关闭测试（`doCheck = false`），以优先保证 Nix sandbox 下稳定产物。
- 版本策略沿用仓库既有约定，使用 `0-unstable-${generated.open-coreui.date}`。
