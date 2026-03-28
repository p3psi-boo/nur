{
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.srv-us;
in
buildGoModule {
  pname = sourceInfo.pname;
  version = sourceInfo.version;

  src = sourceInfo.src;

  modRoot = "backend";
  subPackages = [ "." ];

  # Upstream vendor directory is stale; use proxy vendor instead.
  proxyVendor = true;
  vendorHash = "sha256-1RfS+o/6d8Njw3CYxNVcRtztgSrT/2Hb5H/V8ycdiIg=";

  postPatch = ''
        substituteInPlace backend/main.go \
          --replace-fail 'import (' 'import (
    	"path/filepath"' \
          --replace-fail 'b32encoder = base32.NewEncoding("abcdefghijklmnopqrstuvwxyz234567").WithPadding(base64.NoPadding)' \
    'b32encoder = base32.NewEncoding("abcdefghijklmnopqrstuvwxyz234567").WithPadding(base64.NoPadding)

    	// Load banner from USAGE.txt at startup (read once, cached in memory)
    	banner = func() string {
    		cwd, err := os.Getwd()
    		if err != nil {
    			return ""
    		}
    		data, err := os.ReadFile(filepath.Join(cwd, "USAGE.txt"))
    		if err != nil {
    			return ""
    		}
    		return string(data)
    	}()' \
          --replace-fail 'BannerCallback: func(conn ssh.ConnMetadata) string {
    			return "Usage: ssh " + *domain + " -R 1:localhost:3000 -R 2:192.168.0.1:80 …\r\nIf you get a Permission denied error, first generate a key with ssh-keygen -t ed25519\r\n"
    		},' \
            'BannerCallback: func(conn ssh.ConnMetadata) string { return banner },'
  '';

  ldflags = [
    "-s"
    "-w"
  ];

  # 运行时性能优化
  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
  };

  buildFlags = [ "-gcflags=all=-l=4" ];

  postInstall = ''
    mv $out/bin/backend $out/bin/srvus
  '';

  meta = {
    description = "Expose local services over TLS via SSH reverse tunnels";
    homepage = "https://github.com/pcarrier/srv.us";
    license = lib.licenses.isc;
    mainProgram = "srvus";
  };
}
