{
  lib,
  buildGoModule,
  generated,
}:

let
  sourceInfo = generated.cliproxyapi;
in
buildGoModule {
  pname = "cliproxyapi";
  version = lib.removePrefix "v" sourceInfo.version;

  src = sourceInfo.src;

  subPackages = [ "cmd/server" ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
    # 使用公共 Go 代理镜像，避免 Google proxy 的 abuse/rate-limit
    GOPROXY = "https://goproxy.cn";
    GOSUMDB = "sum.golang.google.cn";
  };

  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=${sourceInfo.version}"
    "-X=main.Commit=unknown"
    "-X=main.BuildDate=unknown"
  ];

  overrideModAttrs = old: {
    preBuild = ''
      export GOPROXY="https://goproxy.cn"
      export GOSUMDB="off"
      # Remove test file that imports v6 of this module (circular test dependency not in go.mod)
      rm -f sdk/cliproxy/auth/request_auth_prepare_test.go
    '';
  };

  vendorHash = "sha256-AIue9XBsfsKGClRLB1DCME+36crapnOdQrEICFYG1a0=";

  postInstall = ''
    if [ -e "$out/bin/server" ]; then
      mv "$out/bin/server" "$out/bin/cliproxyapi"
    fi

    install -Dm644 config.example.yaml "$out/share/cliproxyapi/config.example.yaml"
  '';

  doCheck = false;

  meta = {
    description = "OpenAI/Gemini/Claude/Codex compatible API proxy for CLI tools";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    downloadPage = "https://github.com/router-for-me/CLIProxyAPI/releases";
    changelog = "https://github.com/router-for-me/CLIProxyAPI/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "cliproxyapi";
  };
}
