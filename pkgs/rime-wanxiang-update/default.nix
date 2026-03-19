{
  python3,
  lib,
  fetchurl,
}:

python3.pkgs.buildPythonApplication {
  pname = "rime-wanxiang-update";
  version = "6.2.4";
  format = "other";

  src = fetchurl {
    url = "https://github.com/rimeinn/rime-wanxiang-update-tools/releases/latest/download/rime-wanxiang-update-win-mac-ios-android.py";
    sha256 = "1gxa0rv3263y80qifhm9c4p4nk3yzrzlikixmxib7l3w7xzhp98g";
  };

  propagatedBuildInputs = with python3.pkgs; [
    requests
    tqdm
  ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # 创建 bin 目录
    mkdir -p $out/bin

    # 添加 Python shebang 并复制脚本
    echo "#!${python3}/bin/python3" > $out/bin/rime-wanxiang-update
    cat $src >> $out/bin/rime-wanxiang-update
    chmod +x $out/bin/rime-wanxiang-update

    runHook postInstall
  '';

  meta = with lib; {
    description = "Rime 万象方案更新助手 - 用于自动更新 Rime 输入法的万象方案文件";
    longDescription = ''
      这是一个用于自动更新 Rime 输入法万象方案的 Python 脚本。
      支持从 GitHub 或 CNB 镜像下载最新的方案文件、词典和语法模型。

      功能特性：
      - 自动检查并更新方案文件
      - 支持多种辅助码表 (flypy, hanxin, moqi, tiger, wubi, hanxin, shouyou 等)
      - 支持词典和语法模型更新
      - 自动部署到 fcitx5、ibus 或鼠须管
      - 支持用户自定义排除文件
      - 支持 Windows、macOS、Linux、iOS、Android 多平台
    '';
    homepage = "https://github.com/rimeinn/rime-wanxiang-update-tools";
    license = licenses.mit;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "rime-wanxiang-update";
  };
}
