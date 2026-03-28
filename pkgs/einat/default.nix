{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  llvmPackages,
  bpftools,
  libbpf,
  elfutils,
  zlib,
  enableIpv6 ? true,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "einat";
  version = "0.1.9";

  src = fetchFromGitHub {
    owner = "EHfive";
    repo = "einat-ebpf";
    rev = "v0.1.9";
    hash = "sha256-0S4od60X5j7wWD9mV/jUuJ8EwJ+OLYM2bnUTjr0pozo=";
  };

  cargoHash = "sha256-IX95AnLYMtVrkQY/nLEgTq44m6I1z/HiT7MXVGv2epM=";

  nativeBuildInputs = [
    pkg-config
    llvmPackages.clang-unwrapped
    bpftools
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    libbpf
    elfutils
    zlib
  ];

  buildFeatures = [
    "aya"
    "libbpf"
  ]
  ++ lib.optionals enableIpv6 [ "ipv6" ];

  # Optimize for runtime performance (not binary size)
  CARGO_BUILD_INCREMENTAL = "false";
  CARGO_PROFILE_RELEASE_STRIP = "symbols";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "3";  # 最高运行时性能
  CARGO_PROFILE_RELEASE_LTO = "thin";     # thin LTO 平衡编译和运行时
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "0";  # 自动并行
  CARGO_PROFILE_RELEASE_PANIC = "abort";

  # The eBPF programs need special permissions to load
  meta = with lib; {
    description = "An eBPF-based Endpoint-Independent(Full Cone) NAT";
    homepage = "https://github.com/EHfive/einat-ebpf";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
    # Requires kernel >= 5.15 and eBPF support
    broken = stdenv.isAarch64; # May have issues on ARM64
    mainProgram = "einat";
  };
})
