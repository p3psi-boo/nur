{
  lib,
  stdenv,
  stdenvNoCC,
  generated,
  dpkg,
  patchelf,
  fprintd,
  glib,
  gusb,
  pixman,
  nss,
  libgudev,
  polkit,
  linuxPackages,
}:

let
  sourceInfo = generated.focaltech-fingerprint;

  debSrc = builtins.fetchurl {
    url = "https://github.com/oneXfive/ubuntu_spi/raw/main/libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_20250112_amd64.deb";
    sha256 = "1h9n3mzibshl7v802yl4nrxviyzgz8w5a3jjrjxsm41gfg1r735l";
    name = "libfprint-focaltech.deb";
  };

  kernelModuleFor = {
    kernel,
    useAltDriver ? false,
  }:
    stdenv.mkDerivation {
      pname = "focaltech-spi-${kernel.modDirVersion}";
      version = "1.0.3-unstable-${sourceInfo.date}";

      src = sourceInfo.src;

      postPatch = lib.optionalString useAltDriver ''
        cp alt/focal_spi.c focal_spi.c
      '' + ''
        # Linux 6.18+ dropped asm/unaligned.h for out-of-tree module builds.
        # The header lives under source/include/linux/unaligned.h in nixpkgs kernels.
        if [ -e "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/source/include/linux/unaligned.h" ] \
          || [ -e "${kernel.dev}/lib/modules/${kernel.modDirVersion}/source/include/linux/unaligned.h" ] \
          || [ -e "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/linux/unaligned.h" ]; then
          substituteInPlace focal_spi.c \
            --replace-fail '<asm/unaligned.h>' '<linux/unaligned.h>'
        fi
      '';

      makeFlags = [
        "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      ];

      installPhase = ''
        runHook preInstall
        install -D focal_spi.ko \
          $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/spi/focal_spi.ko
        runHook postInstall
      '';

      meta = with lib; {
        description = "Focaltech fingerprint reader SPI driver (FTE3600/4800/6600/6900)";
        homepage = "https://github.com/vobademi/FTEXX00-Ubuntu";
        license = licenses.gpl2Only;
        platforms = platforms.linux;
      };
    };

  runtimeLibPath = lib.makeLibraryPath [
    glib
    gusb
    pixman
    nss
    libgudev
  ];

  fprintdRuntimePath = lib.makeLibraryPath [
    glib
    polkit
  ];
in
stdenvNoCC.mkDerivation rec {
  pname = "focaltech-fingerprint";
  version = "1.94.4+tod1-0ubuntu1~22.04.2_spi_20250112";

  src = debSrc;

  nativeBuildInputs = [
    dpkg
    patchelf
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -R $src debdir
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    # Start from the regular nixpkgs fprintd package and replace the linked libfprint.
    cp -aL ${fprintd}/. $out/
    chmod -R u+w $out

    substituteInPlace \
      $out/lib/systemd/system/fprintd.service \
      $out/share/dbus-1/system-services/net.reactivated.Fprint.service \
      --replace ${fprintd} $out

    mkdir -p $out/lib
    cp debdir/usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 $out/lib/
    ln -s libfprint-2.so.2.0.0 $out/lib/libfprint-2.so.2

    if [ -d debdir/lib/udev/rules.d ]; then
      mkdir -p $out/lib/udev/rules.d
      cp debdir/lib/udev/rules.d/* $out/lib/udev/rules.d/
    fi

    patchelf --set-rpath ${runtimeLibPath} \
      $out/lib/libfprint-2.so.2.0.0

    patchelf --set-rpath $out/lib:${fprintdRuntimePath} \
      $out/libexec/fprintd

    runHook postInstall
  '';

  passthru = {
    inherit kernelModuleFor;
    kernelModule = kernelModuleFor {
      kernel = linuxPackages.kernel;
    };
    nixosModule = import ./module.nix;
  };

  meta = with lib; {
    description = "Focaltech fingerprint reader bundle for NixOS (kernel module + patched fprintd)";
    longDescription = ''
      Bundles the Focaltech SPI kernel driver together with a patched fprintd
      package that uses the proprietary Focaltech libfprint binary extracted
      from the Ubuntu driver package.

      Supported devices include FTE3600, FTE4800, FTE6600 and FTE6900.
    '';
    homepage = "https://github.com/vobademi/FTEXX00-Ubuntu";
    license = licenses.unfreeRedistributable or licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
