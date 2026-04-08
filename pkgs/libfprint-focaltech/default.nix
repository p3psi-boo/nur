{
  lib,
  stdenv,
  dpkg,
  makeWrapper,
  libfprint,
  glib,
  nss,
  openssl,
  libusb1,
  pixman,
  fprintd,
  stdenvNoCC,
}:

# libfprint 的 Focaltech 专有驱动
# 这是一个闭源二进制驱动，需要配合 focaltech-spi 内核模块使用
stdenvNoCC.mkDerivation rec {
  pname = "libfprint-focaltech";
  version = "1.94.4+tod1-0ubuntu1~22.04.2_spi_20250112";

  src = builtins.fetchurl {
    url = "https://github.com/oneXfive/ubuntu_spi/raw/main/libfprint-2-2_1.94.4+tod1-0ubuntu1~22.04.2_spi_20250112_amd64.deb";
    sha256 = "1h9n3mzibshl7v802yl4nrxviyzgz8w5a3jjrjxsm41gfg1r735l";
    name = "libfprint-focaltech.deb";
  };

  nativeBuildInputs = [ dpkg ];

  unpackPhase = ''
    dpkg-deb -R $src debdir
  '';

  installPhase = ''
    runHook preInstall

    # 安装主要的库文件
    mkdir -p $out/lib
    cp -r debdir/usr/lib/x86_64-linux-gnu/* $out/lib/

    # 安装 udev 规则
    mkdir -p $out/lib/udev/rules.d
    if [ -d debdir/lib/udev/rules.d ]; then
      cp debdir/lib/udev/rules.d/* $out/lib/udev/rules.d/
    fi

    # 安装设备固件（如果有）
    if [ -d debdir/usr/lib/firmware ]; then
      mkdir -p $out/lib/firmware
      cp -r debdir/usr/lib/firmware/* $out/lib/firmware/
    fi

    # 安装模块配置文件
    mkdir -p $out/etc/modules-load.d
    mkdir -p $out/etc/modprobe.d

    # fprintd 服务覆盖配置
    mkdir -p $out/etc/systemd/system/fprintd.service.d
    cat > $out/etc/systemd/system/fprintd.service.d/focaltech-override.conf << 'EOF'
    [Service]
    DeviceAllow=/dev/focal_moh_spi rw
    EOF

    runHook postInstall
  '';

  # 这个包与官方 libfprint 冲突，需要特别处理
  # 安装后需要覆盖系统的 libfprint-2.so.2
  passthru = {
    # 提供原始 so 文件路径供其他包使用
    libfprint-so = "lib/libfprint-2.so.2.0.0";
  };

  meta = with lib; {
    description = "Focaltech fingerprint reader proprietary libfprint driver";
    longDescription = ''
      Proprietary driver for Focaltech fingerprint readers (FTE3600/4800/6600/6900).
      This is a closed-source binary driver that requires the focaltech-spi kernel module.

      To use this driver:
      1. Install focaltech-spi kernel module
      2. Load the focal_spi module: modprobe focal_spi
      3. This library overrides the standard libfprint for Focaltech devices

      Note: This driver is not open source and is distributed as a binary blob.
    '';
    homepage = "https://github.com/oneXfive/ubuntu_spi";
    # 闭源驱动，但原始仓库没有明确许可证
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
