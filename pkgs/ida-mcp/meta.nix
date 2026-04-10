# Meta configuration for ida-mcp package
{ pkgs, ... }:

{
  # Pass ida-pro as an extra dependency
  extraArgs = pkgs: {
    ida-pro = pkgs.ida-pro or (pkgs.callPackage ../ida-pro { });
  };
}
