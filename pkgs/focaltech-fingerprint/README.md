# focaltech-fingerprint

Unified NixOS package for Focaltech SPI fingerprint readers.

Supported devices:

- FTE3600
- FTE4800
- FTE6600
- FTE6900

This package combines:

- the `focal_spi` kernel module built from `vobademi/FTEXX00-Ubuntu`
- a patched `fprintd` bundle using the proprietary Focaltech `libfprint` binary

## Status

This package is intended to provide a single entry point for NixOS use.

It exposes:

- `pkgs.focaltech-fingerprint` — patched userspace package
- `pkgs.focaltech-fingerprint.kernelModuleFor { kernel = ...; }` — kernel module builder
- `pkgs.focaltech-fingerprint.nixosModule` — NixOS module

## Recommended usage

Use the included NixOS module:

```nix
{
  imports = [
    pkgs.focaltech-fingerprint.nixosModule
  ];

  hardware.focaltechFingerprint.enable = true;
}
```

If your device shows `init sensor error!`, try:

```nix
{
  imports = [ pkgs.focaltech-fingerprint.nixosModule ];

  hardware.focaltechFingerprint = {
    enable = true;
    useAltDriver = true;
  };
}
```

## What the module does

When enabled, it automatically:

- adds the kernel module to `boot.extraModulePackages`
- loads `focal_spi`
- enables `services.fprintd`
- uses the bundled patched `fprintd`
- installs bundled udev rules

## Notes

- The userspace fingerprint driver is proprietary.
- This package currently targets `x86_64-linux`.
- Source bundle for the userspace part is extracted from the Ubuntu `.deb` package referenced by upstream.
