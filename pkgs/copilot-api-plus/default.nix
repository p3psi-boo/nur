{
  lib,
  stdenv,
  makeWrapper,
  nodejs,
  generated,
  writeShellScriptBin,
}:

let
  sourceInfo = generated.copilot-api-plus;

  # 启动脚本
  launcher = writeShellScriptBin "copilot-api-plus" ''
    set -e

    PACKAGE_NAME="copilot-api-plus"
    PACKAGE_VERSION="1.2.25"
    CACHE_DIR="$HOME/.cache/copilot-api-plus-nix"

    # 检查缓存是否有效
    if [ -f "$CACHE_DIR/node_modules/.package-version" ]; then
      CACHED_VERSION=$(cat "$CACHE_DIR/node_modules/.package-version" 2>/dev/null || echo "")
      if [ "$CACHED_VERSION" != "$PACKAGE_VERSION" ]; then
        echo "Package version changed, clearing cache..."
        rm -rf "$CACHE_DIR"
      fi
    fi

    # 如果缓存不存在，安装包
    if [ ! -d "$CACHE_DIR/node_modules/$PACKAGE_NAME" ]; then
      echo "First run: Installing copilot-api-plus..."
      mkdir -p "$CACHE_DIR"
      cd "$CACHE_DIR"

      # 创建最小 package.json
      cat > package.json << 'PKGJSON'
{
  "name": "copilot-api-plus-runner",
  "version": "1.0.0",
  "dependencies": {
    "copilot-api-plus": "1.2.25"
  }
}
PKGJSON

      # 安装依赖
      if ! ${nodejs}/bin/npm install --omit=dev --no-audit --no-fund 2>&1; then
        echo "Error: Failed to install dependencies"
        exit 1
      fi

      # 记录版本
      echo "$PACKAGE_VERSION" > node_modules/.package-version
      echo "Installation complete!"
    fi

    # 运行程序
    exec ${nodejs}/bin/node "$CACHE_DIR/node_modules/copilot-api-plus/dist/main.js" "$@"
  '';
in

stdenv.mkDerivation {
  pname = "copilot-api-plus";
  version = "0-unstable-${sourceInfo.date}";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ${launcher}/bin/copilot-api-plus $out/bin/
    chmod +x $out/bin/copilot-api-plus

    runHook postInstall
  '';

  meta = {
    description = "Turn GitHub Copilot into OpenAI/Anthropic API compatible server";
    homepage = "https://github.com/imbuxiangnan-cyber/copilot-api-plus";
    license = lib.licenses.mit;
    mainProgram = "copilot-api-plus";
    platforms = lib.platforms.all;
    longDescription = ''
      This package provides a wrapper that automatically downloads and caches
      copilot-api-plus from npm on first run.

      The package will be cached in ~/.cache/copilot-api-plus-nix/
    '';
  };
}
