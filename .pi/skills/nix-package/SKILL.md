---
name: nixpkgs-packaging-standard
description: A comprehensive guide and rule set for packaging software within the Nixpkgs ecosystem. It ensures packages are reproducible, maintainable, and compliant with modern Nixpkgs standards (2025+), including the mandatory by-name structure, proper dependency categorization, and validation workflows. Use this when initializing new packages, updating existing ones, or reviewing Nix expressions for nixpkgs submission.
---

## 1. 核心工作流与结构
### 📂 目录规范 (By-Name)
所有新包**必须**遵循 `pkgs/by-name` 结构：
* **路径**：`pkgs/by-name/<pname-前两位>/<pname>/package.nix`
* **示例**：`ripgrep` -> `pkgs/by-name/ri/ripgrep/package.nix`
* **注意**：`by-name` 内的包会自动在 `all-packages.nix` 中注册，严禁手动修改 `all-packages.nix`（除非是复杂的覆盖逻辑）。

### 📝 命名规范
* `pname`: 全小写，使用 kebab-case（如 `my-awesome-tool`）。
* `version`: 必须以数字开头。若无 tag 则用 `0-unstable-YYYY-MM-DD`。

---

## 2. 推荐代码模板 (finalAttrs 模式)
优先使用 `finalAttrs` 以支持更优雅的 `passthru.tests` 和 `overrideAttrs`。

```nix
{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
# 其他依赖...
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "example-tool";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "author";
    repo = "example-tool";
    rev = "v${finalAttrs.version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # 1. 构建工具 (跨平台编译时不运行在目标机)
  nativeBuildInputs = [ cmake pkg-config ];
  # 2. 运行时库 (链接到二进制文件)
  buildInputs = [ ];

  # 优先使用 flags 而非复写 phase
  cmakeFlags = [ "-DENABLE_FEATURE=ON" ];

  # 若需修改源码，优先在 postPatch 中使用 substituteInPlace
  postPatch = ''
    substituteInPlace Makefile --replace "/usr/bin" "$out/bin"
  '';

  doCheck = true;

  passthru = {
    tests.version = testers.testVersion { package = finalAttrs.finalPackage; };
    updateScript = nix-update-script { };
  };

  meta = with lib; {
    description = "A concise description starting with capital, no period";
    homepage = "https://github.com/author/example-tool";
    license = licenses.mit;
    maintainers = with maintainers; [ yourhandle ];
    platforms = platforms.unix;
    mainProgram = "example-tool";
  };
})
```

---

## 3. 依赖分类指南
| 类别 | 用途 | 常见例子 |
| :--- | :--- | :--- |
| **nativeBuildInputs** | 构建时工具（Host 架构） | `cmake`, `pkg-config`, `go`, `rustc` |
| **buildInputs** | 运行时依赖库（Target 架构） | `openssl`, `zlib`, `glib` |
| **propagatedBuildInputs** | 必须传递给下游的依赖 | Python 库依赖、某些开发库 |
| **nativeCheckInputs** | 仅 `checkPhase` 需要的工具 | `pytest`, `gtest` |

---

## 4. 黄金律：必须避免的事项 (Anti-Patterns)
* ❌ **绝对路径**：严禁硬编码 `/usr`, `/bin`, `/etc`。使用 `substituteInPlace` 替换为 `$out` 或依赖包路径。
* ❌ **网络访问**：构建过程中严禁尝试连接网络（Sandbox 会拦截）。所有资源必须通过 `fetch*` 预先下载。
* ❌ **非确定性**：严禁在构建中引入时间戳、随机数。
* ❌ **过度复写**：不要直接重写 `buildPhase`，优先利用已有的 `buildRustPackage` 或 `cmakeFlags`。
* ❌ **命名混淆**：不要在 `pname` 里包含 `nix` 或版本号。
* ❌ **缺少 Meta**：不能缺少 `license` 或 `platforms`。

---

## 5. 语言特定 Builder 快速索引
* **Rust**: `buildRustPackage { cargoHash = "..."; }`
* **Go**: `buildGoModule { vendorHash = "..."; }`
* **Python**: `buildPythonApplication { format = "pyproject"; }`
* **Node.js**: `buildNpmPackage { npmDepsHash = "..."; }`

---

## 6. 提交前的 Checklist
1.  [ ] **Format**: 运行 `nixfmt` 格式化代码。
2.  [ ] **Build**: `nix-build -A pname` 在本地 Sandbox 成功。
3.  [ ] **Review**: 运行 `nixpkgs-review wip` 检查受影响范围。
4.  [ ] **Lint**: 运行 `statix check` 和 `deadnix`。
5.  [ ] **Commit Message**: 遵循规范 `pname: init at 1.2.3` 或 `pname: 1.2.2 -> 1.2.3`。
