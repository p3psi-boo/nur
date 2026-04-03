{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nodejs_22,
  generated,
}:

let
  sourceInfo = generated.bb-browser;
  # 从 GitHub release tag 提取版本号 (bb-browser-v0.11.2 -> 0.11.2)
  version = lib.removePrefix "bb-browser-v" sourceInfo.version;
in
stdenv.mkDerivation {
  pname = "bb-browser";
  inherit version;

  # 从 npm registry 获取预构建的包
  src = fetchurl {
    url = "https://registry.npmjs.org/bb-browser/-/bb-browser-${version}.tgz";
    hash = "sha256-dmJ5giBzT4ZHnmnc3BUAa6ey/nlU/HahDdvstKWpKNE=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    # npm 包是 gzip 压缩的 tarball
    tar -xzf $src
    # 解压后会得到 'package' 目录
    cd package
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # 创建输出目录
    mkdir -p $out/lib/bb-browser

    # 复制所有文件
    cp -r . $out/lib/bb-browser/

    # 创建 bin 目录
    mkdir -p $out/bin

    # 创建包装器脚本
    makeWrapper ${nodejs_22}/bin/node $out/bin/bb-browser \
      --add-flags "$out/lib/bb-browser/dist/cli.js"

    makeWrapper ${nodejs_22}/bin/node $out/bin/bb-browser-mcp \
      --add-flags "$out/lib/bb-browser/dist/mcp.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Your browser is the API. CLI + MCP server for AI agents to control Chrome with your login state.";
    homepage = "https://github.com/epiral/bb-browser";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "bb-browser";
  };
}
