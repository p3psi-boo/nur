{
  buildGoModule,
  stdenv,
  cmake,
  pkg-config,
  fcitx5,
  dbus,
  pipewire,
  makeWrapper,
  generated,
  lib,
  withFcitx5 ? true,  # 默认启用 fcitx5 模块
  # Opus 库依赖（CGO 编译需要）
  libopus,
  opusfile,
  libogg,
}:

let
  sourceInfo = generated.coe;
  version = "0-unstable-${sourceInfo.date}";

  # Opus 相关构建输入
  opusBuildInputs = [
    libopus
    opusfile
    libogg
  ];

  # CGO flags for opus headers
  CGO_CFLAGS = builtins.concatStringsSep " " [
    "-I${libogg.dev}/include"
    "-I${libopus.dev}/include"
  ];

  # pkg-config path for opus libraries
  PKG_CONFIG_PATH = builtins.concatStringsSep ":" [
    "${libopus.dev}/lib/pkgconfig"
    "${opusfile.dev}/lib/pkgconfig"
    "${libogg.dev}/lib/pkgconfig"
  ];

  # coe 主程序（Go 构建）
  coeMain = buildGoModule {
    pname = "coe";
    inherit version;

    src = sourceInfo.src;

    nativeBuildInputs = [
      pkg-config
    ];

    buildInputs = opusBuildInputs;

    # 运行时性能优化环境 + Opus CGO 配置
    env = {
      CGO_ENABLED = "1";
      GOFLAGS = "-trimpath";
      GOAMD64 = "v3";  # x86-64-v3 指令集优化
    };

    preBuild = ''
      export CGO_CFLAGS="${CGO_CFLAGS}"
      export CGO_LDFLAGS="-L${libopus}/lib -L${opusfile}/lib -L${libogg}/lib"
      export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}"
    '';

    # Upstream v0.0.6 misses the module checksum line required by `go mod vendor`.
    postPatch = ''
      grep -q '^golang.org/x/sys v0.40.0 h1:' go.sum || \
        echo 'golang.org/x/sys v0.40.0 h1:DBZZqJ2Rkml6QMQsZywtnjnnGvHza6BTfYFWY9kjEWQ=' >> go.sum
    '';

    vendorHash = "sha256-hmdZV8tyRivKEQEQA47gRB9N6Eof6Cf3mbZRKTK9yZQ=";

    # 运行时性能优化
    ldflags = [
      "-s"
      "-w"
      "-X main.version=${sourceInfo.version}"
      "-X main.builtBy=nix"
    ];

    # 启用激进内联优化
    buildFlags = [ "-gcflags=all=-l=4" ];

    meta = {
      description = "Zero-GUI Linux voice input tool";
      homepage = "https://github.com/p3psi-boo/coe";
      mainProgram = "coe";
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux;
    };
  };

  # fcitx5 模块（C++ 构建）- 从 coe 源码中的 packaging/fcitx5 目录构建
  coeFcitx5Module = stdenv.mkDerivation {
    pname = "coe-fcitx5";
    inherit version;

    # 使用主源码的 packaging/fcitx5 子目录
    src = sourceInfo.src;

    # 动态设置 sourceRoot，因为 fetchgit 的目录名是 coe-<rev>
    setSourceRoot = ''
      export sourceRoot=$(echo */packaging/fcitx5)
    '';

    nativeBuildInputs = [
      cmake
      pkg-config
    ];

    buildInputs = [
      fcitx5
      dbus
    ];

    # 新版 fcitx5 头文件使用 C++20 特性，需要覆盖 CMakeLists.txt 中的 C++17
    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace "CMAKE_CXX_STANDARD 17" "CMAKE_CXX_STANDARD 20"
    '';

    cmakeFlags = [
      "-DFCITX_INSTALL_USE_FCITX_SYS_PATHS=OFF"
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/fcitx5
      cp libcoefcitx.so $out/lib/fcitx5/

      mkdir -p $out/share/fcitx5/addon
      cp ../addon/coe.conf $out/share/fcitx5/addon/

      runHook postInstall
    '';

    meta = {
      description = "Coe Fcitx5 input method module for voice input";
      homepage = "https://github.com/p3psi-boo/coe";
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux;
    };
  };
in

# 组合包：主程序 + 可选的 fcitx5 模块
stdenv.mkDerivation {
  pname = "coe";
  inherit version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/fcitx5 $out/share/fcitx5/addon

    # 复制主程序并包装，添加 pw-record 到 PATH
    makeWrapper ${coeMain}/bin/coe $out/bin/coe \
      --prefix PATH : "${pipewire}/bin"

    # 复制 fcitx5 模块（如果启用）
    ${lib.optionalString withFcitx5 ''
      cp ${coeFcitx5Module}/lib/fcitx5/libcoefcitx.so $out/lib/fcitx5/
      cp ${coeFcitx5Module}/share/fcitx5/addon/coe.conf $out/share/fcitx5/addon/
    ''}

    runHook postInstall
  '';

  # 传递依赖
  propagatedBuildInputs = lib.optionals withFcitx5 [
    fcitx5
    dbus
  ];

  passthru = {
    mainProgram = "coe";
    inherit coeMain coeFcitx5Module;
  };

  meta = {
    description = "Zero-GUI Linux voice input tool (with Fcitx5 module)";
    homepage = "https://github.com/p3psi-boo/coe";
    mainProgram = "coe";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
