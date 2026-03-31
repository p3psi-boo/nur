# Nix 配置入口 - 简化版
# 所有 Nix 相关的配置集中管理

{ inputs }:

{
  # nixpkgs 配置
  nixpkgs = import ./config/nixpkgs.nix;

  # CI 检查配置
  ci = import ./config/ci.nix;
}
