{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.focaltechFingerprint;
  bundle = cfg.package;
  kernelModule = bundle.kernelModuleFor {
    kernel = config.boot.kernelPackages.kernel;
    useAltDriver = cfg.useAltDriver;
  };
in
{
  options.hardware.focaltechFingerprint = {
    enable = lib.mkEnableOption "Focaltech SPI fingerprint reader support";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.focaltech-fingerprint;
      description = "Focaltech fingerprint bundle package to use.";
    };

    useAltDriver = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Use the alternative upstream focal_spi.c implementation.
        Enable this if the default driver reports `init sensor error!`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [ kernelModule ];
    boot.kernelModules = [ "focal_spi" ];

    services.fprintd.enable = true;
    services.fprintd.package = bundle;

    services.udev.packages = [ bundle ];
  };
}
