{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  generated,
}:

stdenv.mkDerivation (finalAttrs: {
  inherit (generated.magiskboot-bin) pname version src;

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q $src
    runHook postUnpack
  '';

  installPhase =
    let
      archMap = {
        x86_64-linux = "lib/x86_64/libmagiskboot.so";
        aarch64-linux = "lib/arm64-v8a/libmagiskboot.so";
        i686-linux = "lib/x86/libmagiskboot.so";
        armv7l-linux = "lib/armeabi-v7a/libmagiskboot.so";
      };
      libPath =
        archMap.${stdenv.hostPlatform.system}
          or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
    in
    ''
      runHook preInstall
      install -Dm755 ${libPath} $out/bin/magiskboot
      runHook postInstall
    '';

  meta = with lib; {
    description = "magiskboot binary from Magisk official release";
    homepage = "https://github.com/topjohnwu/Magisk";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "i686-linux"
      "armv7l-linux"
    ];
    mainProgram = "magiskboot";
  };
})
