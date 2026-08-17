{
  lib,
  stdenv,
  generated,
  linuxPackages,
  kernel ? linuxPackages.kernel,
}:

let
  sourceInfo = generated.lotspeed;
in
stdenv.mkDerivation {
  pname = "lotspeed-${kernel.modDirVersion}";
  version = "0-unstable-${sourceInfo.date}";

  inherit (sourceInfo) src;

  makeFlags = "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

  postPatch = ''
    kernelTcpHeader=${kernel.dev}/lib/modules/${kernel.modDirVersion}/source/include/net/tcp.h

    # Linux/XanMod with Accurate ECN replaced TCP_ECN_OK with explicit ECN
    # modes. Use the kernel's semantic helper when that API is available while
    # retaining compatibility with the older BBRv3 kernel supported upstream.
    if grep -q 'tcp_ecn_mode_any' "$kernelTcpHeader"; then
      substituteInPlace lotspeed.c \
        --replace-fail \
          '(tcp_sk(sk)->ecn_flags & TCP_ECN_OK)' \
          'tcp_ecn_mode_any(tcp_sk(sk))'
    fi
  '';

  installPhase = ''
    mkdir -p $out/lib/modules/${kernel.modDirVersion}/misc
    for x in $(find . -name '*.ko'); do
      cp $x $out/lib/modules/${kernel.modDirVersion}/misc/
    done
  '';

  meta = with lib; {
    description = "LotSpeed adaptive TCP congestion control and NeoQ kernel modules";
    homepage = "https://github.com/uk0/lotspeed/tree/adaptive-accel";
    platforms = platforms.linux;
    maintainers = with maintainers; [ imlonghao ];
  };
}
