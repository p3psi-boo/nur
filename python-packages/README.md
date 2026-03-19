# Python package overlays

这里放仓库级 Python overlay 拆分文件。

约定：
- `default.nix` 只负责聚合 `pythonPackagesExtensions`
- 每个文件尽量只处理一个包或一类很小的 override
- 文件参数约定优先使用：
  - `final`：拿 `lib`、`fetchPypi`、`stdenvNoCC` 等顶层能力
  - `python-final`：拿 `buildPythonPackage` 和 Python 依赖
  - `python-prev`：给已有包做 override

当前拆分：
- `picosvg.nix`：关闭测试
- `idapro.nix`：自定义 `idapro` 包
- `cocoindex.nix`：`cocoindex` 平台相关 wheel 包装

后续新增 Python override 时，优先直接在这里新建单独文件，不再回退到单个大文件。
