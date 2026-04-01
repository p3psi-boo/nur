{
  lib,
  stdenvNoCC,
  fetchurl,
  libime,
  imewlconverter,
  writeText,
}:

let
  # RIME dictionary YAML header
  rimeHeader = writeText "rime-header.yaml" ''
    ---
    name: CustomPinyinDictionary
    version: "${version}"
    sort: by_weight
    use_preset_vocabulary: false
    ...
  '';
  version = "20260101";
in
stdenvNoCC.mkDerivation {
  pname = "rime-custom-pinyin-dictionary";
  inherit version;

  src = fetchurl {
    url = "https://github.com/wuhgit/CustomPinyinDictionary/releases/download/assets/CustomPinyinDictionary_Fcitx.dict";
    sha256 = "sha256-Y2d7DhvNknbo7u9BVTq1Mr9gYSeFWNnvo2KbDr6INuU=";
  };

  nativeBuildInputs = [
    libime
    imewlconverter
  ];

  dontUnpack = true;

  buildPhase = ''
    runHook preBuild

    # Convert fcitx5 dict format to libime txt format
    libime_pinyindict -d "$src" temp.txt

    # Convert libime txt format to RIME yaml format
    ImeWlConverterCmd -i:libpy temp.txt -o:rime CustomPinyinDictionary.raw.yaml

    # Add RIME header to the dictionary file
    cat ${rimeHeader} > CustomPinyinDictionary.dict.yaml
    # Skip the first line (---) from the raw output since we already have it in header
    tail -n +2 CustomPinyinDictionary.raw.yaml >> CustomPinyinDictionary.dict.yaml

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/rime-data
    install -Dm644 CustomPinyinDictionary.dict.yaml -t $out/share/rime-data/

    runHook postInstall
  '';

  meta = with lib; {
    description = "RIME 自建拼音输入法词库，百万常用词汇量";
    longDescription = ''
      自建拼音输入法词库，包含百万常用词汇量。
      针对日常输入习惯，当前词库包含了人文类、地理类、生活类等内容。
      本包将 Fcitx5 格式的词库转换为 RIME 格式。
    '';
    homepage = "https://github.com/wuhgit/CustomPinyinDictionary";
    license = with licenses; [
      cc-by-sa-40
      fdl12Plus
    ];
    maintainers = [ ];
    platforms = platforms.all;
  };
}
