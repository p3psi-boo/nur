{ stdenv
, lib
, fetchFromGitHub
, clang
, clang_18
, bpftools
, libbpf
, libffi
, linuxHeaders
, pkg-config
, python3
, makeWrapper
, enableStatic ? false
}:

stdenv.mkDerivation {
  pname = "mimic";
  version = "unstable-2024-12-09";

  src = fetchFromGitHub {
    owner = "hack3ric";
    repo = "mimic";
    rev = "493faf5dfd440bc44bc0d2a88baaca4d7ef0b709";
    hash = "sha256-UQlnWDl39Fri1q38l9Z/ybrmMP6QoRHuqLV/y/Ab8Eg=";
  };

  nativeBuildInputs = [
    clang
    clang_18
    bpftools
    pkg-config
    python3
    makeWrapper
  ];

  buildInputs = [
    libbpf
    libffi
    linuxHeaders
  ];

  makeFlags = [
    "PREFIX=${placeholder "out"}"
    "RUNTIME_DIR=/run/mimic"
    "BPF_USE_SYSTEM_VMLINUX=1"
    "BPFTOOL=${bpftools}/bin/bpftool"
    "CC=${stdenv.cc.targetPrefix}gcc"
    "BPF_CC=${clang_18}/bin/clang"
    "LLVM_STRIP=${clang_18}/bin/llvm-strip"
    "BPF_CFLAGS=--target=bpf -mcpu=v3 -g -O2 -iquote. -Wall -Wextra -std=gnu99"
  ] ++ lib.optionals enableStatic [
    "STATIC=1"
  ];

  postPatch = ''
    # Fix hardcoded paths
    substituteInPlace Makefile \
      --replace "/usr/sbin/bpftool" "bpftool"

    # Use system vmlinux from build inputs
    echo "Using system vmlinux from linux headers"
  '';

  # Build only userspace components - kernel modules need DKMS
  buildPhase = ''
    runHook preBuild

    # Build BPF objects manually with unwrapped clang
    ${clang_18}/bin/clang --target=bpf -mcpu=v3 -g -O2 -iquote. -Wall -Wextra -std=gnu99 \
      -DMIMIC_BPF_TARGET_ARCH_x86_64 -DMIMIC_CHECKSUM_HACK_kfunc -DMIMIC_BPF \
      -c -o bpf/egress.o bpf/egress.c

    ${clang_18}/bin/clang --target=bpf -mcpu=v3 -g -O2 -iquote. -Wall -Wextra -std=gnu99 \
      -DMIMIC_BPF_TARGET_ARCH_x86_64 -DMIMIC_CHECKSUM_HACK_kfunc -DMIMIC_BPF \
      -c -o bpf/ingress.o bpf/ingress.c

    # Generate BPF skeleton header
    ${bpftools}/bin/bpftool gen skeleton bpf/egress.o > src/bpf_skel.h

    # Build CLI tools
    make build-cli build-tools

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install CLI tool
    if [ -f mimic ]; then
      install -D -m 755 mimic $out/bin/mimic
    fi

    # Install tools
    for tool in mimic-pcap mimic-dump; do
      if [ -f "$tool" ]; then
        install -D -m 755 "$tool" $out/bin/"$tool"
      fi
    done

    # Install man pages if they exist
    if [ -d docs/man ]; then
      find docs/man -name "*.1" -exec install -D -m 644 {} $out/share/man/man1/ \;
    fi

    # Install documentation
    mkdir -p $out/share/doc/mimic
    cp README.md LICENSE $out/share/doc/mimic/

    runHook postInstall
  '';

  # Runtime files that will be created by the daemon
  postInstall = ''
    mkdir -p $out/var/run/mimic
  '';

  passthru = {
    tools = [
      "mimic-pcap"
      "mimic-dump"
    ];
    isLinux = stdenv.isLinux;
  };

  meta = {
    description = "UDP to TCP obfuscator based on eBPF";
    longDescription = ''
      Mimic is a UDP to TCP obfuscator designed to bypass UDP QoS and port blocking.
      Based on eBPF, it directly mangles data inside Traffic Control (TC) subsystem
      in the kernel space and restores data using XDP, achieving remarkably high
      performance compared to other projects.
    '';
    homepage = "https://github.com/hack3ric/mimic";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "mimic";
  };
}