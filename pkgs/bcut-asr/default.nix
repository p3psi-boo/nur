{
  buildGoModule,
  generated,
  lib,
  ffmpeg,
}:

let
  sourceInfo = generated.bcut-asr;
in
buildGoModule {
  pname = "bcut-asr";
  version = sourceInfo.version;

  src = sourceInfo.src;

  vendorHash = "sha256-54bWaa/2jl+2UjcFi+UQD6M+T2W4eO2jZ8/ZFr2kqQ4=";

  # 运行时性能优化
  env = {
    CGO_ENABLED = "0";
    GOFLAGS = "-trimpath";
    GOAMD64 = "v3";
  };

  ldflags = [
    "-s"
    "-w"
  ];

  buildFlags = [ "-gcflags=all=-l=4" ];

  nativeBuildInputs = [ ffmpeg ];

  doCheck = false;

  postInstall = ''
    mv $out/bin/bcut $out/bin/bcut-asr
  '';

  meta = {
    description = "使用必剪API的语音字幕识别 (Go版本)";
    homepage = "https://github.com/p3psi-boo/bcut-asr-go";
    license = lib.licenses.mit;
    mainProgram = "bcut-asr";
  };
}
