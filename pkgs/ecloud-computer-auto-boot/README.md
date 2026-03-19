# ecloud-computer-auto-boot

移动云电脑自动开机工具的 Nix 打包。

## 构建说明

该项目依赖中国移动云的 SDK，通过公开的 Go 代理访问：
- `gitlab.ecloud.com/ecloud/ecloudsdkcomputer`
- `gitlab.ecloud.com/ecloud/ecloudsdkcore`

这些依赖托管在私有 GitLab 实例上，但可通过中国移动的 Go 代理 `https://ecloud.10086.cn/api/query/developer/nexus/repository/go-sdk/` 公开访问。

## 构建要求

由于需要网络访问来下载依赖，构建时需要禁用沙箱：

```bash
nix build .#ecloud-computer-auto-boot --impure --option sandbox false
```

## 包信息

- **版本**: 1.0.0
- **许可证**: MIT
- **主程序**: `ecloud_computer_auto_boot`
- **二进制大小**: ~12MB (静态链接)

## 上游信息

- 项目主页：https://github.com/Samler-Lee/ecloud_computer_auto_boot
- Docker 镜像：`samlerlee/ecloud_computer_auto_boot:latest`
