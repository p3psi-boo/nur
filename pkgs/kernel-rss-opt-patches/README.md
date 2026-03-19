# Kernel RSS Stat Optimization Patches

Linux 内核补丁系列，用于优化单线程任务的 RSS (Resident Set Size) 统计初始化和销毁性能。

## 作者

Gabriel Krisman Bertazi <krisman@suse.de>

## 来源

- 邮件列表讨论: https://lore.kernel.org/lkml/20251127233635.4170047-1-krisman@suse.de/
- 补丁状态: RFC (Request for Comments)
- 提交日期: 2025-11-27

## 补丁概述

此补丁系列实现了一个**双模式计数器机制**来优化内存管理中的 RSS 统计：

1. **初始模式（单线程）**: 使用简单计数器，避免昂贵的 per-CPU 内存分配
2. **升级模式（多线程）**: 当内存管理结构被共享时（如创建线程），自动升级为完整的 per-CPU 计数器

### 补丁列表

1. **0001-lib-percpu_counter-helper.patch**
   提取 CPU 热插拔监视列表的辅助函数

2. **0002-lazy-percpu-counter.patch**
   实现延迟初始化的 per-CPU 计数器基础设施

3. **0003-mm-counter-optimization.patch**
   将延迟计数器应用于 MM RSS 统计

4. **0004-mm-split-slow-path.patch**
   分离本地/远程计数器更新路径以进一步优化

## 性能提升

在 256 核系统上的基准测试结果：

| 工作负载 | 系统时间改善 | 说明 |
|---------|------------|------|
| `/bin/true` (20000次) | **11%** | fork 密集型工作负载 |
| kernbench | **1.4%** | 内核编译基准测试 |
| gitsource | **3.12%** | Git 源代码操作 |
| 多线程测试 | **2-4%** | 创建线程的微基准测试 |

### mm_init 性能分析

在 256 核机器上，`mm_init` 函数的采样占比：
- **之前**: 13.5% → **之后**: 3.33%
- per-CPU 内存分配开销从 4.80% 降至可忽略不计

## 在 NixOS 中使用

### 方式 1: 应用所有补丁

```nix
# 在你的 configuration.nix 或主机配置中
{
  boot.kernelPatches = pkgs.kernel-rss-opt-patches.all;

  # 使用你的内核包
  boot.kernelPackages = pkgs.linuxPackages_cachyos-lto.cachyOverride {
    mArch = "ZEN4";
  };
}
```

### 方式 2: 选择性应用补丁

```nix
{
  boot.kernelPatches = with pkgs.kernel-rss-opt-patches; [
    percpu-counter-helper
    lazy-percpu-counter
    mm-counter-optimization
    # 可选：如果需要进一步优化
    mm-split-slow-path
  ];
}
```

### 方式 3: 在自定义内核中使用

如果你正在构建自定义内核：

```nix
{
  boot.kernelPackages = let
    baseKernel = pkgs.linuxPackages_cachyos-lto;
  in baseKernel.kernel.override {
    kernelPatches = (baseKernel.kernel.kernelPatches or [])
      ++ pkgs.kernel-rss-opt-patches.all;
  };
}
```

## 技术细节

### 工作原理

1. **延迟初始化**: 进程创建时，RSS 计数器初始化为简单计数器而非 per-CPU 计数器
2. **本地更新**: 单线程进程的更新通过简单的算术操作完成
3. **远程更新**: 来自其他 CPU 的更新通过原子操作处理
4. **自动升级**: 当进程变为多线程（`CLONE_VM`），计数器升级为 per-CPU 版本

### 适用场景

- ✅ **高频 fork** 短生命周期进程（如 shell 脚本中的命令执行）
- ✅ **单线程应用** CoreUtils 工具链
- ✅ **容器工作负载** 大量短生命周期容器
- ⚠️ **多线程应用** 仍然有 2-4% 的小幅提升

## 兼容性注意事项

### 内核版本
这些补丁针对 **Linux 主线内核** (6.12+) 开发。

### CachyOS 内核兼容性
CachyOS 内核已包含大量优化补丁，可能与此补丁系列存在：
- ✅ 无冲突（理想情况）
- ⚠️ 部分重叠（部分优化已存在）
- ❌ 冲突（需要调整）

**建议**: 在测试环境中先验证补丁是否能成功应用并正常工作。

### 测试建议

1. 在非生产环境测试：
   ```bash
   nixos-rebuild test
   ```

2. 检查内核日志是否有错误：
   ```bash
   dmesg | grep -i "patch\|error\|warning"
   ```

3. 运行性能基准测试验证改进：
   ```bash
   # fork 密集型测试
   time for i in {1..10000}; do /bin/true; done

   # 编译测试
   time nix-build '<nixpkgs>' -A linux
   ```

## 补丁状态

- **RFC 阶段**: 这些补丁仍在审查中，可能会有变化
- **上游合并**: 尚未合并到主线内核
- **生产使用**: 在充分测试后可用于生产环境

## 相关链接

- [LKML 讨论线程](https://lore.kernel.org/lkml/20251127233635.4170047-1-krisman@suse.de/)
- [之前的性能回归报告](https://lore.kernel.org/all/20230608111408.s2minsenlcjow7q3@quack3)

## 故障排除

### 补丁应用失败

如果补丁无法应用到你的内核：

```bash
# 检查内核版本
uname -r

# 查看 nix build 日志
nix-build --keep-failed
cd /tmp/nix-build-*
cat build.log
```

可能的原因：
1. 内核版本不匹配
2. CachyOS 已包含类似补丁
3. 上下文行号不匹配

### 运行时问题

如果系统不稳定或性能下降：

1. 使用之前的配置启动
2. 移除这些补丁
3. 在 GitHub Issues 中报告问题

## 许可证

这些补丁遵循 **GPL-2.0** 许可证，与 Linux 内核相同。

## 贡献

如果你发现问题或有改进建议：

1. 在 nix-cfg 仓库中创建 issue
2. 提交补丁到 LKML（针对上游问题）
3. 分享你的性能测试结果
