# Wallos 包与 NixOS 模块支持原生部署。

Wallos 用于管理订阅费用。包提供 PHP 应用文件，模块使用 Nginx、PHP-FPM
和 SQLite 运行应用，不依赖 Docker。PHP-FPM 负责接收 Nginx 转交的 PHP 请求。

## 构建命令会生成只读应用目录。

在本仓库根目录运行 `nix build .#wallos`，`result` 指向包含 `index.php` 的应用目录。
包没有命令行启动器；单独安装包不会启动 Web 服务。

版本由 `nvfetcher.toml` 的 `wallos` 条目维护。构建时运行上游 PHP 测试，
PHP 运行环境可通过包的 `php` 属性取得。

## 导入模块后可以启用服务。

下面的 `nur` 是本仓库的 flake input 名，`wallos.example.org` 是示例域名。

```nix
{ inputs, ... }:
{
  imports = [ inputs.nur.nixosModules.wallos ];

  suites.wallos = {
    enable = true;
    hostName = "wallos.example.org";
  };

  services.nginx.virtualHosts."wallos.example.org" = {
    enableACME = true;
    forceSSL = true;
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@example.org";
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
```

通过传统 NUR 入口使用时，从本仓库 `default.nix` 的返回值取得 `modules.wallos` 并导入。
模块自行取得 Wallos 包，无需额外添加 overlay。

执行主机原有的 NixOS 部署命令后，访问配置的域名并注册首个用户。
模块不自动开放防火墙或申请证书。已有反向代理时，可通过
`services.nginx.virtualHosts.<hostName>.listen` 将 Nginx 限制到本地地址：

```nix
services.nginx.virtualHosts."wallos.example.org".listen = [
  { addr = "127.0.0.1"; port = 8080; }
];
```

这里的 8080 是示例端口，实际值应与主机现有服务配置一致。

## 模块保留数据库和上传文件。

`suites.wallos.dataDir` 默认是 `/var/lib/wallos`。数据库位于其 `db` 子目录，
上传图片位于 `logos` 子目录，导入和恢复使用 `tmp` 子目录。
模块将应用代码保存在只读 Nix store 中，仅上述目录可由 `wallos` 用户写入。
Nginx 阻止直接读取数据库、临时文件和 PHP include 文件，并阻止执行上传目录中的 PHP 文件。

`wallos-init.service` 在 PHP-FPM 启动前创建数据库并运行迁移。
更新应用可能改变数据库结构；回退 NixOS 配置不会回退数据库，更新前应备份数据目录。
上游 `cronjobs` 文件中的任务全部对应 `wallos-*.timer`，日志通过
`journalctl -u wallos-init -u phpfpm-wallos` 或具体任务的 service 查看。
任务使用主机时区；未设置主机时区时，PHP 保留默认配置。

模块沿用上游的 256M 上传限制，以及 15 个 PHP 子进程和每进程 500 次请求限制。
`suites.wallos.poolSettings` 可以覆盖 PHP 进程配置，进程按请求启动。
包不改写 PHP 业务代码；运行时仍由 PHP 执行原应用并读写 SQLite。
模块构建时额外生成带状态目录链接的应用副本，不在每次服务启动时复制应用。

## 测试覆盖应用构建与模块运行。

包构建运行上游 `tests/run.php`。`checks.x86_64-linux.wallos-module` 是 NixOS
虚拟机测试，检查初始化、注册页面、定时任务、文件访问限制及服务重启后的数据保留。
运行 `nix build .#checks.x86_64-linux.wallos-module` 可执行该测试。
