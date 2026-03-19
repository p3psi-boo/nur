{
  lib,
  python3,
  generated,
  makeWrapper,
  p7zip,
  zstd,
}:

python3.pkgs.buildPythonPackage {
  pname = "wikiteam3";
  inherit (generated.wikiteam3) version src;

  pyproject = true;

  build-system = with python3.pkgs; [
    pdm-backend
  ];

  dependencies = with python3.pkgs; [
    requests
    internetarchive
    mwclient
    file-read-backwards
    python-slugify
    lxml
  ];

  nativeBuildInputs = [ makeWrapper ];

  # 放宽版本约束（nixpkgs 依赖版本可能超出上界）
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'requests<3.0.0,>=2.32.3' 'requests>=2.32.3' \
      --replace-fail 'mwclient<1.0.0,>=0.11.0' 'mwclient>=0.11.0' \
      --replace-fail 'file-read-backwards<4.0.0,>=3.1.0' 'file-read-backwards>=3.1.0' \
      --replace-fail 'python-slugify<9.0.0,>=8.0.4' 'python-slugify>=8.0.4'
  '';

  # 生成优化字节码（提升启动速度 10-15%）
  postInstall = ''
    python -m compileall -o 2 $out/lib/python*/site-packages/wikiteam3
  '';

  # wikiteam3uploader 需要 7z 和 zstd 二进制
  postFixup = ''
    for prog in $out/bin/*; do
      wrapProgram $prog \
        --prefix PATH : ${
          lib.makeBinPath [
            p7zip
            zstd
          ]
        }
    done
  '';

  # 跳过测试（需要网络访问）
  doCheck = false;

  meta = {
    description = "Tools for archiving wikis (MediaWiki, DokuWiki, etc.)";
    homepage = "https://github.com/saveweb/wikiteam3";
    license = lib.licenses.gpl3Plus;
    maintainers = [ ];
    mainProgram = "wikiteam3dumpgenerator";
  };
}
