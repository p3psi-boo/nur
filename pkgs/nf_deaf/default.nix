{ lib
, stdenv
, generated
, makeWrapper
, which
}:

stdenv.mkDerivation (finalAttrs: {
  dontBuild = true;
  pname = "nf_deaf";
  version = "0-unstable-${generated.nf_deaf.date}";

  src = generated.nf_deaf.src;

  nativeBuildInputs = [
    makeWrapper
    which
  ];

  installPhase = ''
    runHook preInstall

    # Install the source files
    mkdir -p $out/share/nf_deaf/src
    cp -r * $out/share/nf_deaf/src/

    # Install documentation
    mkdir -p $out/share/doc/nf_deaf
    cp README.md README_EN.md LICENSE $out/share/doc/nf_deaf/ 2>/dev/null || true

    # Create a build script
    mkdir -p $out/bin
    cat > $out/bin/build-nf_deaf << 'EOF'
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if we have kernel headers
    if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
        echo "Error: Kernel headers not found at /lib/modules/$(uname -r)/build"
        echo "Please install kernel headers: apt-get install linux-headers-$(uname -r) or equivalent"
        exit 1
    fi

    # Copy source to a temporary directory
    WORK_DIR=$(mktemp -d)
    trap "rm -rf $WORK_DIR" EXIT

    echo "Building nf_deaf in $WORK_DIR..."
    cp -r @out@/share/nf_deaf/src/* $WORK_DIR/

    # Build the kernel module
    cd $WORK_DIR
    make -j$(nproc)

    echo "Build completed successfully!"
    echo "Module built at: $WORK_DIR/nf_deaf.ko"
    echo ""
    echo "To load the module:"
    echo "  sudo insmod $WORK_DIR/nf_deaf.ko"
    echo "To unload the module:"
    echo "  sudo rmmod nf_deaf"
    echo ""
    echo "Note: The module will be removed when this shell exits."
    echo "Copy it to a permanent location if you want to keep it."

    # Keep the working directory accessible for a while
    echo "Press Enter to clean up the build directory..."
    read -r
    EOF

    # Make the build script executable
    chmod +x $out/bin/build-nf_deaf

    # Replace the placeholder with actual path
    substituteInPlace $out/bin/build-nf_deaf --replace "@out@" "$out"

    runHook postInstall
  '';

  meta = {
    description = "Linux kernel module for network testing that sends crafted packets after successful TCP handshake";
    longDescription = ''
      nf_deaf is a Linux kernel module that allows network testing by sending
      crafted packets after a successful TCP handshake. It works with nftables/iptables
      to mark packets for processing and supports various configurations for TTL settings,
      checksum errors, and other network testing scenarios.

      This package provides the source code and a build script to compile the kernel module
      against your running kernel.
    '';
    homepage = "https://github.com/kmb21y66/nf_deaf";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ "bubu" ];
    platforms = lib.platforms.linux;
    mainProgram = "build-nf_deaf";
  };
})