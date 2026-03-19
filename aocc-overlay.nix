final: prev:

let
  wrapCCWith =
    {
      cc,
      bintools ? prev.stdenv.cc.bintools,
      libc ? bintools.libc,
      ...
    }@extraArgs:
    prev.callPackage (prev.path + "/pkgs/build-support/cc-wrapper") (
      let
        self = {
          nativeTools =
            prev.stdenv.targetPlatform == prev.stdenv.hostPlatform && (prev.stdenv.cc.nativeTools or false);
          nativeLibc =
            prev.stdenv.targetPlatform == prev.stdenv.hostPlatform && (prev.stdenv.cc.nativeLibc or false);
          nativePrefix = prev.stdenv.cc.nativePrefix or "";
          noLibc = !self.nativeLibc && (libc == null);

          isGNU = cc.isGNU or false;
          isClang = cc.isClang or false;

          inherit cc bintools libc;
        }
        // extraArgs;
      in
      self
    );

  aoccPackages =
    {
      version,
      sha256,
      libcxx ? null,
      bintools ? null,
    }:
    let
      unwrapped = prev.callPackage ./pkgs/aoccUnwrapped {
        inherit version sha256;
        rocm-runtime = prev.rocmPackages.rocm-runtime;
        libffi = final.libffi_3_2;
      };
    in
    rec {
      inherit unwrapped;
      aocc = wrapCCWith (
        {
          cc = unwrapped;
        }
        // prev.lib.optionalAttrs (libcxx != null) { inherit libcxx; }
        // prev.lib.optionalAttrs (bintools != null) { inherit bintools; }
      );
      stdenv = prev.overrideCC prev.stdenv aocc;
    };
in
{
  inherit aoccPackages;

  aoccPackages_510 = aoccPackages {
    version = "5.1.0";
    # https://www.amd.com/en/developer/aocc.html
    # https://www.amd.com/en/developer/aocc/eula/aocc-5-1-eula.html?filename=aocc-compiler-5.1.0.tar
    sha256 = "0s9cs8syz9q6kihd41kn1whn1i9bamrlpcpy6za10vn6k7imdjrw";
  };

  aoccPackages_latest = final.aoccPackages_510;
  aocc = final.aoccPackages_latest.aocc;
  aoccStdenv = final.aoccPackages_latest.stdenv;
}
