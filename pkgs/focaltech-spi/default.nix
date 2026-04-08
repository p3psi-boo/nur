{
  lib,
  stdenv,
  generated,
  kernel,
  useAltDriver ? false,  # 某些设备使用官方代码会出现 "init sensor error!"，此时需要启用此选项
}:

let
  sourceInfo = generated.focaltech-spi;
in
stdenv.mkDerivation {
  pname = "focaltech-spi-${kernel.modDirVersion}";
  version = "1.0.3-unstable-${sourceInfo.date}";

  inherit (sourceInfo) src;

  # 使用 alt 版本的驱动（修复某些设备的 init sensor error）
  postPatch = lib.optionalString useAltDriver ''
    cp alt/focal_spi.c focal_spi.c
  '' + ''
    # 修复 kernel 6.12+ 的头文件变更
    if [ ''${kernel.modDirVersion%%.*} -ge 6 ] && [ ''${kernel.modDirVersion#*.} -ge 12 ] 2>/dev/null || [ ''${kernel.modDirVersion%%.*} -gt 6 ] 2>/dev/null; then
      substituteInPlace focal_spi.c \
        --replace '<asm/unaligned.h>' '<linux/unaligned.h>'
    fi
  '';

  makeFlags = [
    "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall

    # 压缩内核模块
    xz focal_spi.ko

    # 安装到标准内核模块路径
    install -D focal_spi.ko.xz \
      $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/spi/focal_spi.ko.xz

    runHook postInstall
  '';

  meta = with lib; {
    description = "Focaltech fingerprint reader SPI driver (FTE3600/4800/6600/6900)";
    longDescription = ''
      Kernel module for Focaltech fingerprint readers over SPI.
      Supports FTE3600, FTE4800, FTE6600 and FTE6900 models.

      Note: Some devices may experience "init sensor error!" with the official driver.
      Set useAltDriver = true to use the alternative driver implementation.
    '';
    homepage = "https://github.com/vobademi/FTEXX00-Ubuntu";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
