{
  extraArgs = pkgs: {
    version = "5.1.0";
    # https://www.amd.com/en/developer/aocc.html
    # https://www.amd.com/en/developer/aocc/eula/aocc-5-1-eula.html?filename=aocc-compiler-5.1.0.tar
    sha256 = "0s9cs8syz9q6kihd41kn1whn1i9bamrlpcpy6za10vn6k7imdjrw";

    # Satisfy AOCC binary deps
    rocm-runtime = pkgs.rocmPackages.rocm-runtime;
    libffi = pkgs.libffi_3_2;
  };
}
