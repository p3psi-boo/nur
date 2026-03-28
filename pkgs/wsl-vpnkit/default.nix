{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  iproute2,
  iptables,
  iputils,
  busybox,
  gawk,
  generated,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "wsl-vpnkit";
  version = generated.wsl-vpnkit.version;

  # Fetch the prebuilt release tarball
  src = fetchurl {
    url = "https://github.com/sakai135/wsl-vpnkit/releases/download/${finalAttrs.version}/wsl-vpnkit.tar.gz";
    hash = "sha256-UJ73bm/A1NlFJHsI8yPeWzTGx84LVzdmgOuK1+OnTtU=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # Runtime dependencies for the shell script
  # Note: busybox is NOT in buildInputs to avoid polluting build-time PATH
  # (its find doesn't support -printf, breaking fixup phase)
  runtimeDeps = [
    iproute2
    iptables
    iputils
    busybox # Provides nslookup, wget (~1 MiB vs dnsutils 65 MiB)
    gawk # busybox awk is limited, use full gawk
  ];

  unpackPhase = ''
    runHook preUnpack

    # Extract only the app/ directory from the tarball
    mkdir -p app
    tar -xzf $src --strip-components=1 -C app app/

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/wsl-vpnkit

    # Install binaries
    install -Dm755 app/wsl-vm $out/libexec/wsl-vpnkit/wsl-vm
    install -Dm755 app/wsl-gvproxy.exe $out/libexec/wsl-vpnkit/wsl-gvproxy.exe

    # Install main script with wrapper
    install -Dm755 app/wsl-vpnkit $out/libexec/wsl-vpnkit/wsl-vpnkit

    # Create wrapper that sets correct paths
    makeWrapper $out/libexec/wsl-vpnkit/wsl-vpnkit $out/bin/wsl-vpnkit \
      --set VMEXEC_PATH "$out/libexec/wsl-vpnkit/wsl-vm" \
      --set GVPROXY_PATH "$out/libexec/wsl-vpnkit/wsl-gvproxy.exe" \
      --prefix PATH : ${lib.makeBinPath finalAttrs.runtimeDeps}

    # Install systemd service if present
    if [ -f app/wsl-vpnkit.service ]; then
      mkdir -p $out/lib/systemd/system
      install -Dm644 app/wsl-vpnkit.service $out/lib/systemd/system/wsl-vpnkit.service
      
      # Patch service file to use standalone script mode instead of distro mode
      substituteInPlace $out/lib/systemd/system/wsl-vpnkit.service \
        --replace-fail 'ExecStart=/mnt/c/Windows/system32/wsl.exe -d wsl-vpnkit --cd /app wsl-vpnkit' "ExecStart=$out/bin/wsl-vpnkit" \
        --replace-fail '#Environment=VMEXEC_PATH=/full/path/to/wsl-vm GVPROXY_PATH=/full/path/to/wsl-gvproxy.exe' "Environment=VMEXEC_PATH=$out/libexec/wsl-vpnkit/wsl-vm GVPROXY_PATH=$out/libexec/wsl-vpnkit/wsl-gvproxy.exe"
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Provides network connectivity to WSL 2 when blocked by VPN";
    longDescription = ''
      wsl-vpnkit uses gvisor-tap-vsock to provide network connectivity to WSL 2
      distros when access is blocked by VPN software. Requires WSL 2 environment.
    '';
    homepage = "https://github.com/sakai135/wsl-vpnkit";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ]; # WSL 2 specific
    mainProgram = "wsl-vpnkit";
  };
})
