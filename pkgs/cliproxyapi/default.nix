{
  buildGo126Module ? buildGoModule,
  buildGoModule,
  generated,
  lib,
}:

let
  sourceInfo = generated.cliproxyapi;
  pkgVersion = lib.removePrefix "v" sourceInfo.version;
in
buildGo126Module (finalAttrs: {
  pname = "cli-proxy-api";
  version = pkgVersion;

  src = sourceInfo.src;

  subPackages = [ "cmd/server" ];

  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";  # x86-64-v3 指令集优化
  };

  # 运行时性能优化
  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=${sourceInfo.version}"
    "-X=main.Commit=unknown"
    "-X=main.BuildDate=unknown"
  ];

  # 启用激进内联优化
  buildFlags = [ "-gcflags=all=-l=4" ];

  vendorHash = "sha256-3h68+GSEvd7tcJOqTjV2KXBXZFX7AWg3r8K3zZe4DnI=";

  postInstall = ''
    if [ -e "$out/bin/server" ]; then
      mv "$out/bin/server" "$out/bin/cli-proxy-api"
    fi

    install -Dm644 config.example.yaml "$out/share/cli-proxy-api/config.example.yaml"
  '';

  doCheck = false;

  meta = {
    description = "OpenAI/Gemini/Claude/Codex compatible API proxy for CLI tools";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    downloadPage = "https://github.com/router-for-me/CLIProxyAPI/releases";
    changelog = "https://github.com/router-for-me/CLIProxyAPI/releases/tag/${sourceInfo.version}";
    license = lib.licenses.mit;
    mainProgram = "cli-proxy-api";
  };
})
