# Android Reverse Tools - GitHub 开源与打包进度

根据 `android-reverse-tools.md` 中提到的工具，结合 GitHub 仓库信息与当前打包结果，整理如下。

## 已确认在 GitHub 开源

### 已尝试并完成打包

- [x] **SoFixer**
  - GitHub: https://github.com/F8LEFT/SoFixer
  - 状态：已添加 NUR 包 `sofixer`
  - 说明：CMake 项目，已验证 `nix build .#sofixer` 与 `nix run .#sofixer -- -h`

- [x] **uber-apk-signer**
  - GitHub: https://github.com/patrickfav/uber-apk-signer
  - 状态：已添加 NUR 包 `uber-apk-signer`
  - 说明：Maven 项目，已验证 `nix build .#uber-apk-signer` 与 `nix run .#uber-apk-signer -- --version`

- [x] **smali/baksmali**
  - GitHub: https://github.com/JesusFreke/smali
  - 状态：已添加 NUR 包 `smali`
  - 说明：Gradle 多模块项目，已验证 `nix build .#smali`、`nix run .#smali -- --help` 与 `baksmali --help`

### GitHub 开源，但暂未继续打包

- [ ] **dnSpy**
  - GitHub: https://github.com/dnSpy/dnSpy
  - 说明：开源，但仓库已归档

- [x] **ClassyShark**
  - GitHub: https://github.com/google/android-classyshark
  - 状态：已添加 NUR 包 `classyshark`
  - 说明：GUI 工具，已验证 `nix build .#classyshark` 与 `nix run .#classyshark -- --help`

- [x] **JD-GUI**
  - GitHub: https://github.com/java-decompiler/jd-gui
  - 状态：已添加 NUR 包 `jd-gui`
  - 说明：GUI 工具，已验证 `nix build .#jd-gui`，运行入口在无图形环境下会触发预期的 AWT Headless 异常

- [ ] **Il2CppDumper**
  - GitHub: https://github.com/Perfare/Il2CppDumper
  - 说明：.NET 项目

- [ ] **unidbg**
  - GitHub: https://github.com/zhkl0228/unidbg
  - 说明：Java 项目，依赖较多

- [ ] **UnityStudio**
  - GitHub: https://github.com/Perfare/UnityStudio
  - 说明：Unity/.NET GUI 工具

## GitHub 仓库存在，但不算真正开源

- [ ] **GDA**
  - GitHub: https://github.com/charles2gan/GDA-android-reversing-Tool
  - 说明：README 明确写了 `This is not an open source project`

## 已在 nixpkgs 中存在，继续跳过

- **Frida**
- **Ghidra**
- **jadx**
- **apktool**
- **dex2jar**
- **enjarify**
- **androguard**
- **ILSpy**
- **Bytecode Viewer**

## 商业软件或闭源软件，不继续打包

- **IDA Pro**
- **Binary Ninja**
- **JEB**
- **Charles**
- **GameGuardian**

## 备注

- 这次实际新增了五个包：`sofixer`、`uber-apk-signer`、`smali`、`jd-gui`、`classyshark`
- `nix flake check` 仍被仓库里现有的 `mimic` 检查失败阻塞，和本次新增包无关
