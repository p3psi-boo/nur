{
  extraArgs = pkgs: {
    rustPlatform = pkgs.makeRustPlatform {
      rustc = pkgs.fenix.stable.toolchain;
      cargo = pkgs.fenix.stable.toolchain;
    };
  };
}
