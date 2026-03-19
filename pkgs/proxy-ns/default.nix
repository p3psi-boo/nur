{
  buildGoModule,
  generated,
  lib,
  libcap,
  util-linux,
  runtimeShell,
  coreutils,
}:

let
  sourceInfo = generated.proxy-ns;
in
buildGoModule (finalAttrs: {
  pname = "proxy-ns";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = null;

  env.CGO_ENABLED = "0";

  nativeBuildInputs = [
    libcap
    util-linux
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  subPackages = [ "." ];

  postInstall = ''
    mv $out/bin/proxy-ns $out/bin/.proxy-ns-wrapped
    cat > $out/bin/proxy-ns <<EOF
    #!${runtimeShell}
    exec ${util-linux}/bin/setpriv \
      --inh-caps="+sys_admin,+net_admin,+net_bind_service,+sys_chroot,+chown" \
      --ambient-caps="+sys_admin,+net_admin,+net_bind_service,+sys_chroot,+chown" \
      --reuid=\$(${coreutils}/bin/id -u) \
      --regid=\$(${coreutils}/bin/id -g) \
      --keep-groups \
      $out/bin/.proxy-ns-wrapped "\$@"
    EOF
    chmod +x $out/bin/proxy-ns
  '';

  meta = {
    description = "A simple proxy server with network namespace support";
    homepage = "https://github.com/OkamiW/proxy-ns";
    license = lib.licenses.mit;
    mainProgram = "proxy-ns";
    platforms = lib.platforms.linux;
  };
})
